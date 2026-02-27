import 'package:core/core.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/databases/mongo/data_mongodb.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/storage/local_media_finalization_job.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template local_media_finalization_job_service}
/// A service for handling atomic operations on [LocalMediaFinalizationJob]s.
/// {@endtemplate}
class LocalMediaFinalizationJobService {
  /// {@macro local_media_finalization_job_service}
  LocalMediaFinalizationJobService({
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
  @Deprecated('Use claimJobsInBatch for better performance.')
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

  /// Claims a batch of pending finalization jobs.
  ///
  /// This method is more performant for workers as it reduces database
  /// round-trips. It fetches a batch of jobs, deletes them from the queue,
  /// and returns them for processing.
  ///
  /// Note: This operation is not strictly atomic. In a scenario with multiple
  /// concurrent workers, there's a small chance of a race condition where two
  /// workers could claim the same job. However, for the intended use case of a
  /// single background worker, this approach is safe and efficient.
  ///
  /// - [batchSize]: The maximum number of jobs to claim.
  ///
  /// Returns a list of claimed [LocalMediaFinalizationJob]s. The list will be
  /// empty if no jobs are available.
  Future<List<LocalMediaFinalizationJob>> claimJobsInBatch({
    int batchSize = 10,
  }) async {
    _log.finer(
      'Attempting to claim a batch of $batchSize finalization jobs...',
    );
    try {
      // 1. Find a batch of the oldest jobs.
      final jobsToClaim = await _collection
          .find(
            where.sortBy('createdAt').limit(batchSize),
          )
          .toList();

      if (jobsToClaim.isEmpty) {
        return [];
      }

      // 2. Extract their IDs for the deletion query.
      final jobIds = jobsToClaim.map((doc) => doc['_id'] as ObjectId).toList();

      // 3. Delete the claimed jobs from the collection.
      await _collection.deleteMany(where.oneFrom('_id', jobIds));

      _log.fine('Claimed and removed ${jobsToClaim.length} jobs.');

      // 4. Map the raw documents to the model and return.
      return jobsToClaim.map((doc) {
        final mappedResult = Map<String, dynamic>.from(doc)
          ..['id'] = (doc['_id'] as ObjectId).oid;
        return LocalMediaFinalizationJob.fromJson(mappedResult);
      }).toList();
    } catch (e, s) {
      _log.severe('Error claiming batch of finalization jobs', e, s);
      throw const ServerException('Database error while claiming jobs.');
    }
  }
}
