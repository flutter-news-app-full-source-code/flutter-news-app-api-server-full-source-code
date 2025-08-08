import 'package:core/core.dart';
import 'package:data_mongodb/data_mongodb.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/rate_limit_service.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// The name of the MongoDB collection for storing rate limit attempts.
const String kRateLimitAttemptsCollection = 'rate_limit_attempts';

/// {@template mongodb_rate_limit_service}
/// A MongoDB-backed implementation of [RateLimitService].
///
/// This service tracks request attempts in a dedicated MongoDB collection.
/// It relies on a TTL (Time-To-Live) index on the `createdAt` field to
/// ensure that old request records are automatically purged by the database,
/// which is highly efficient.
/// {@endtemplate}
class MongoDbRateLimitService implements RateLimitService {
  /// {@macro mongodb_rate_limit_service}
  MongoDbRateLimitService({
    required MongoDbConnectionManager connectionManager,
    required Logger log,
  }) : _connectionManager = connectionManager,
       _log = log;

  final MongoDbConnectionManager _connectionManager;
  final Logger _log;

  DbCollection get _collection =>
      _connectionManager.db.collection(kRateLimitAttemptsCollection);

  @override
  Future<void> checkRequest({
    required String key,
    required int limit,
    required Duration window,
  }) async {
    try {
      final now = DateTime.now();
      final windowStart = now.subtract(window);

      // 1. Count recent requests for the given key within the time window.
      final recentRequestsCount = await _collection.count(
        where.eq('key', key).and(where.gte('createdAt', windowStart)),
      );

      _log.finer(
        'Rate limit check for key "$key": Found $recentRequestsCount '
        'requests in the last ${window.inMinutes} minutes (limit is $limit).',
      );

      // 2. If the limit is reached or exceeded, throw an exception.
      if (recentRequestsCount >= limit) {
        _log.warning(
          'Rate limit exceeded for key "$key". '
          '($recentRequestsCount >= $limit)',
        );
        throw const ForbiddenException(
          'You have made too many requests. Please try again later.',
        );
      }

      // 3. If the limit is not reached, record the new request.
      await _collection.insertOne({
        '_id': ObjectId(),
        'key': key,
        'createdAt': now,
      });
      _log.finer('Recorded new request for key "$key".');
    } on HttpException {
      // Re-throw exceptions that we've thrown intentionally.
      rethrow;
    } catch (e, s) {
      _log.severe('Error during rate limit check for key "$key"', e, s);
      throw const OperationFailedException(
        'An unexpected error occurred while checking request rate limits.',
      );
    }
  }

  @override
  void dispose() {
    // This is a no-op because the underlying database connection is managed
    // by the injected MongoDbConnectionManager, which has its own lifecycle.
    _log.finer('dispose() called, no action needed.');
  }
}
