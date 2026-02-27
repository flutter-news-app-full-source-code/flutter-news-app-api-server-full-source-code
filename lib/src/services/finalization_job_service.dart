import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/databases/mongo/data_mongodb.dart';

import 'package:flutter_news_app_api_server_full_source_code/src/models/storage/local_media_finalization_job.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template finalization_job_service}
/// A service for handling atomic operations on [LocalMediaFinalizationJob]s.
/// {@endtemplate}
class FinalizationJobService {
  /// {@macro finalization_job_service}
  FinalizationJobService({
    required MongoDbConnectionManager connectionManager,
    required Logger log,
  }) : _connectionManager = connectionManager,
       _log = log;

  final MongoDbConnectionManager _connectionManager;
  final Logger _log;

  DbCollection get _collection =>
      _connectionManager.db.collection('local_media_finalization_jobs');

  /// Atomically finds and claims a single pending finalization job.
  ///
  /// It sorts by creation time to process jobs in a FIFO manner.
  /// Returns the claimed [LocalMediaFinalizationJob], or `null` if none are
  /// available.
  Future<LocalMediaFinalizationJob?> claimJob() async {
    _log.finer('Attempting to claim a finalization job...');
    try {
      final result = await _collection.findAndModify(
        query: <String, dynamic>{}, // Find any document
        sort: {'createdAt': 1}, // Process oldest first
        remove: true,
      );

      if (result == null) {
        return null;
      }
      // Manually map the '_id' from the database to the 'id' for the model.
      final mappedResult = Map<String, dynamic>.from(result)
        ..['id'] = (result['_id'] as ObjectId).oid;
      return LocalMediaFinalizationJob.fromJson(mappedResult);
    } catch (e, s) {
      _log.severe('Error claiming finalization job', e, s);
      throw const ServerException('Database error while claiming job.');
    }
  }
}
