import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/app_dependencies.dart';
import 'package:logging/logging.dart';

final _log = Logger('MediaCleanupWorker');

/// The main entry point for the standalone Media Cleanup Worker process.
///
/// This script initializes application dependencies and performs cleanup tasks
/// for the media library. Specifically, it finds and deletes `MediaAsset`
/// records that have been in the `pendingUpload` state for more than a
/// configured grace period (e.g., 24 hours) and removes "orphaned" assets
/// that are no longer referenced by any content.
///
/// This executable can be compiled into a native binary and run by a scheduler
/// (e.g., a cron job) to automate database hygiene.
///
/// ### Operational Guidelines
///
/// **Resource Intensity:** High (I/O Bound)
/// - **Task 1 (Stale Pending):** Low impact. Performs an indexed query.
/// - **Task 2 (Orphan Cleanup):** Medium impact. This task now uses a single,
///   efficient database aggregation pipeline to identify orphaned assets.
///
/// **Recommended Schedule:**
/// - Run this worker **once every 24 hours** during off-peak hours (e.g., at 03:00 UTC).
Future<void> main(List<String> args) async {
  // Configure logger for console output.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      // ignore: avoid_print
      print('  ERROR: ${record.error}');
    }
    if (record.stackTrace != null) {
      // ignore: avoid_print
      print('  STACK TRACE: ${record.stackTrace}');
    }
  });

  await AppDependencies.instance.init();

  try {
    _log.info('Starting media cleanup worker...');

    // Task 1: Clean up stale 'pendingUpload' records from the database.
    await _cleanupPendingUploads();

    // Task 2: Clean up 'completed' assets that are no longer referenced.
    await _cleanupOrphanedAssets();

    _log.info('Media cleanup worker finished successfully.');
  } catch (e, s) {
    _log.severe('An error occurred during the media cleanup process.', e, s);
    exit(1);
  } finally {
    await AppDependencies.instance.dispose();
    exit(0);
  }
}

/// Finds and deletes [MediaAsset] records that have been in the
/// `pendingUpload` state for longer than the grace period.
///
/// These records represent uploads that were initiated but never completed,
/// so there is no corresponding file in cloud storage to delete.
Future<void> _cleanupPendingUploads() async {
  _log.info('--- Starting Task: Cleanup Stale Pending Uploads ---');
  final mediaAssetRepository = AppDependencies.instance.mediaAssetRepository;

  const gracePeriod = Duration(hours: 24);
  final cutoffDate = DateTime.now().toUtc().subtract(gracePeriod);

  _log.info(
    'Searching for stale MediaAssets with status "pendingUpload" created before $cutoffDate.',
  );

  String? cursor;
  var hasMore = true;
  var deletedCount = 0;

  while (hasMore) {
    final response = await mediaAssetRepository.readAll(
      filter: {
        'status': MediaAssetStatus.pendingUpload.name,
        'createdAt': {r'$lt': cutoffDate.toIso8601String()},
      },
      pagination: PaginationOptions(limit: 100, cursor: cursor),
    );

    final pendingAssets = response.items;
    if (pendingAssets.isEmpty) {
      hasMore = false;
      break;
    }

    for (final asset in pendingAssets) {
      _log.info('Deleting stale pending asset record: ${asset.id}');
      await mediaAssetRepository.delete(id: asset.id);
      deletedCount++;
    }

    cursor = response.cursor;
    hasMore = response.hasMore;
  }

  _log.info('Successfully deleted $deletedCount stale pending asset records.');
  _log.info('--- Finished Task: Cleanup Stale Pending Uploads ---');
}

/// Finds and deletes [MediaAsset]s that have a `completed` status but are no
/// longer referenced by any parent entity (User, Headline, Topic, Source).
///
/// This is a critical task for cost management, as it removes unused files
/// from cloud storage.
Future<void> _cleanupOrphanedAssets() async {
  _log.info('--- Starting Task: Cleanup Orphaned Completed Assets ---');
  final mediaAssetRepository = AppDependencies.instance.mediaAssetRepository;
  final storageService = AppDependencies.instance.storageService;
  var successCount = 0;
  var failureCount = 0;

  // 1. Use a single, efficient aggregation pipeline to find orphaned assets.
  _log.info('Executing aggregation pipeline to find orphaned assets...');
  final pipeline = [
    // Stage 1: Consider only completed assets.
    {
      r'$match': {'status': MediaAssetStatus.completed.name},
    },
    // Stage 2-5: Perform a left outer join with each parent collection.
    {
      r'$lookup': {
        'from': 'users',
        'localField': '_id',
        'foreignField': 'mediaAssetId',
        'as': 'userRefs',
      },
    },
    {
      r'$lookup': {
        'from': 'headlines',
        'localField': '_id',
        'foreignField': 'mediaAssetId',
        'as': 'headlineRefs',
      },
    },
    {
      r'$lookup': {
        'from': 'topics',
        'localField': '_id',
        'foreignField': 'mediaAssetId',
        'as': 'topicRefs',
      },
    },
    {
      r'$lookup': {
        'from': 'sources',
        'localField': '_id',
        'foreignField': 'mediaAssetId',
        'as': 'sourceRefs',
      },
    },
    // Stage 6: Filter for documents where ALL reference arrays are empty.
    {
      r'$match': {
        'userRefs': {r'$size': 0},
        'headlineRefs': {r'$size': 0},
        'topicRefs': {r'$size': 0},
        'sourceRefs': {r'$size': 0},
      },
    },
  ];

  final aggregationResult = await mediaAssetRepository.aggregate(
    pipeline: pipeline,
  );
  final orphanedAssets = aggregationResult.map((doc) {
    // Manually map the MongoDB `_id` (ObjectId) to the `id` (String)
    // field expected by the MediaAsset.fromJson factory. This is a
    // localized fix to avoid modifying the shared DataMongodb client.
    final newDoc = Map<String, dynamic>.from(doc);
    if (newDoc.containsKey('_id') && newDoc['_id'] != null) {
      newDoc['id'] = (newDoc['_id'] as dynamic).oid;
    }
    return MediaAsset.fromJson(newDoc);
  }).toList();

  if (orphanedAssets.isEmpty) {
    _log.info('No orphaned assets found.');
  } else {
    _log.info('Found ${orphanedAssets.length} orphaned assets to delete.');
    // 2. Delete the orphaned assets
    for (final asset in orphanedAssets) {
      try {
        _log.info(
          'Deleting orphaned asset: ID=${asset.id}, Path=${asset.storagePath}',
        );
        // First, delete the file from cloud storage.
        await storageService.deleteObject(storagePath: asset.storagePath);
        // Then, delete the database record.
        await mediaAssetRepository.delete(id: asset.id);
        successCount++;
      } catch (e, s) {
        _log.severe(
          'Failed to delete orphaned asset ID: ${asset.id}',
          e,
          s,
        );
        failureCount++;
      }
    }
  }

  _log.info(
    'Orphaned asset cleanup finished. Success: $successCount, Failed: $failureCount.',
  );
  _log.info('--- Finished Task: Cleanup Orphaned Completed Assets ---');
}
