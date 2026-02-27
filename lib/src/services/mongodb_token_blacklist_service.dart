import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/databases/mongo/data_mongodb.dart';

import 'package:flutter_news_app_backend_api_full_source_code/src/services/token_blacklist_service.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// The name of the MongoDB collection used for storing blacklisted tokens.
const String kBlacklistedTokensCollection = 'blacklisted_tokens';

/// {@template mongodb_token_blacklist_service}
/// A MongoDB-backed implementation of [TokenBlacklistService].
///
/// Stores blacklisted JWT IDs (jti) in a dedicated MongoDB collection.
/// It leverages a TTL (Time-To-Live) index on the `expiry` field to have
/// MongoDB automatically purge expired tokens, ensuring efficient cleanup.
/// {@endtemplate}
class MongoDbTokenBlacklistService implements TokenBlacklistService {
  /// {@macro mongodb_token_blacklist_service}
  MongoDbTokenBlacklistService({
    required MongoDbConnectionManager connectionManager,
    required Logger log,
  }) : _connectionManager = connectionManager,
       _log = log;

  final MongoDbConnectionManager _connectionManager;
  final Logger _log;

  DbCollection get _collection =>
      _connectionManager.db.collection(kBlacklistedTokensCollection);

  @override
  Future<void> blacklist(String jti, DateTime expiry) async {
    try {
      // The document structure is simple: the JTI is the primary key (_id)
      // and `expiry` is the TTL-indexed field.
      await _collection.insertOne({'_id': jti, 'expiry': expiry});
      _log.info('Blacklisted jti: $jti (expires: $expiry)');
    } on MongoDartError catch (e) {
      // Handle the specific case of a duplicate key error, which means the
      // token is already blacklisted. This is not a failure condition.
      // We check the message because the error type may not be specific enough.
      if (e.message.contains('duplicate key')) {
        _log.warning('Attempted to blacklist an already blacklisted jti: $jti');
        // Swallow the exception as the desired state is already achieved.
        return;
      }
      // For other database errors, rethrow as a standard exception.
      _log.severe('MongoDartError while blacklisting jti $jti: $e');
      throw OperationFailedException('Failed to blacklist token: $e');
    } catch (e) {
      _log.severe('Unexpected error while blacklisting jti $jti: $e');
      throw OperationFailedException('Failed to blacklist token: $e');
    }
  }

  @override
  Future<bool> isBlacklisted(String jti) async {
    try {
      // We only need to check for the existence of the document.
      // The TTL index handles removal of expired tokens automatically,
      // so if a document exists, it is considered blacklisted.
      final result = await _collection.findOne(where.eq('_id', jti));
      return result != null;
    } catch (e) {
      _log.severe('Error checking blacklist for jti $jti: $e');
      throw OperationFailedException('Failed to check token blacklist: $e');
    }
  }

  @override
  Future<void> cleanupExpired() async {
    // This is a no-op because the TTL index on the MongoDB collection
    // handles the cleanup automatically on the server side.
    _log.finer(
      'cleanupExpired() called, but no action is needed due to TTL index.',
    );
    return Future.value();
  }

  @override
  void dispose() {
    // This is a no-op because the underlying database connection is managed
    // by the injected MongoDbConnectionManager, which has its own lifecycle
    // managed by AppDependencies.
    _log.finer('dispose() called, no action needed.');
  }
}
