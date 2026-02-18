import 'dart:io';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/app_dependencies.dart';
import 'package:logging/logging.dart';

final _log = Logger('MediaCleanupWorker');

/// The main entry point for the standalone Media Cleanup Worker process.
///
/// This script initializes application dependencies and performs cleanup tasks
/// for the media library. Specifically, it finds and deletes `MediaAsset`
/// records that have been in the `pendingUpload` state for more than a
/// configured grace period (e.g., 24 hours).
///
/// This executable can be compiled into a native binary and run by a scheduler
/// (e.g., a cron job) to automate database hygiene.
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

  // 1. Fetch all actively referenced mediaAssetIds from parent entities.
  _log.info('Fetching all active media asset references...');
  final referencedIds = <String>{};

  final repositories = <String, DataRepository<dynamic>>{
    'User': AppDependencies.instance.userRepository,
    'Headline': AppDependencies.instance.headlineRepository,
    'Topic': AppDependencies.instance.topicRepository,
    'Source': AppDependencies.instance.sourceRepository,
  };

  // Note: For referencedIds, we still need to load them all to perform the
  // set difference check efficiently. In a massive scale system, this logic
  // would move to a database aggregation or a bloom filter.
  // For now, we paginate the fetching to avoid blowing up memory during the read.
  for (final entry in repositories.entries) {
    final repoName = entry.key;
    final repo = entry.value;
    _log.finer('Querying $repoName for mediaAssetId references...');

    String? refCursor;
    var refHasMore = true;

    while (refHasMore) {
      final response = await repo.readAll(
        filter: {
          'mediaAssetId': {r'$exists': true, r'$ne': null},
        },
        pagination: PaginationOptions(limit: 1000, cursor: refCursor),
      );

      for (final item in response.items) {
        final mediaAssetId = (item as dynamic).mediaAssetId as String?;
        if (mediaAssetId != null && mediaAssetId.isNotEmpty) {
          referencedIds.add(mediaAssetId);
        }
      }

      refCursor = response.cursor;
      refHasMore = response.hasMore;
    }
    _log.finer('Finished scanning $repoName.');
  }
  _log.info(
    'Found a total of ${referencedIds.length} unique active media asset references.',
  );

  // 2. Fetch all 'completed' media assets.
  _log.info('Fetching all "completed" media assets...');

  String? assetCursor;
  var assetHasMore = true;
  var successCount = 0;
  var failureCount = 0;

  while (assetHasMore) {
    final response = await mediaAssetRepository.readAll(
      filter: {'status': MediaAssetStatus.completed.name},
      pagination: PaginationOptions(limit: 100, cursor: assetCursor),
    );

    final batchAssets = response.items;

    // 3. Identify orphans in this batch
    final orphanedAssets = batchAssets
        .where((asset) => !referencedIds.contains(asset.id))
        .toList();

    if (orphanedAssets.isNotEmpty) {
      _log.info(
        'Found ${orphanedAssets.length} orphaned assets in this batch.',
      );

      // 4. Delete the orphaned assets
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

    assetCursor = response.cursor;
    assetHasMore = response.hasMore;
  }

  _log.info(
    'Orphaned asset cleanup finished. Success: $successCount, Failed: $failureCount.',
  );
  _log.info('--- Finished Task: Cleanup Orphaned Completed Assets ---');
}
