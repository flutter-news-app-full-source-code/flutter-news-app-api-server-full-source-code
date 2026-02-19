import 'package:core/core.dart';
import 'package:data_mongodb/data_mongodb.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/storage/local_upload_token.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template upload_token_service}
/// A service dedicated to handling atomic operations for [LocalUploadToken].
/// {@endtemplate}
class UploadTokenService {
  /// {@macro upload_token_service}
  UploadTokenService({
    required MongoDbConnectionManager connectionManager,
    required Logger log,
  }) : _connectionManager = connectionManager,
       _log = log;

  final MongoDbConnectionManager _connectionManager;
  final Logger _log;

  DbCollection get _collection =>
      _connectionManager.db.collection('local_upload_tokens');

  /// Atomically finds and consumes a single-use upload token.
  ///
  /// Returns the [LocalUploadToken] if found and consumed, otherwise `null`.
  Future<LocalUploadToken?> consumeToken(String tokenId) async {
    _log.fine('Attempting to consume upload token: $tokenId');
    try {
      final result = await _collection.findAndModify(
        query: where.id(ObjectId.fromHexString(tokenId)),
        remove: true,
      );

      if (result == null) {
        _log.warning('Upload token not found or already consumed: $tokenId');
        return null;
      }
      // Manually map the '_id' from the database to the 'id' for the model.
      final mappedResult = Map<String, dynamic>.from(result)
        ..['id'] = (result['_id'] as ObjectId).oid;
      return LocalUploadToken.fromJson(mappedResult);
    } catch (e, s) {
      _log.severe('Error consuming upload token $tokenId', e, s);
      throw const ServerException('Database error during token consumption.');
    }
  }
}
