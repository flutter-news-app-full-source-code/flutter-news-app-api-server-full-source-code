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
    _log.info('Starting media cleanup process...');
    final mediaAssetRepository = AppDependencies.instance.mediaAssetRepository;

    // Define the grace period for pending uploads.
    const gracePeriod = Duration(hours: 24);
    final cutoffDate = DateTime.now().toUtc().subtract(gracePeriod);

    _log.info(
      'Searching for orphaned MediaAssets with status "pendingUpload" created before $cutoffDate.',
    );

    // Find all assets that are still pending after the grace period.
    final orphanedAssetsResponse = await mediaAssetRepository.readAll(
      filter: {
        'status': MediaAssetStatus.pendingUpload.name,
        'createdAt': {r'$lt': cutoffDate.toIso8601String()},
      },
    );

    final orphanedAssets = orphanedAssetsResponse.items;

    if (orphanedAssets.isEmpty) {
      _log.info('No orphaned media assets found. Cleanup complete.');
    } else {
      _log.info('Found ${orphanedAssets.length} orphaned assets to delete.');
      for (final asset in orphanedAssets) {
        _log.info('Deleting orphaned asset: ${asset.id}');
        // Deleting the database record for a 'pendingUpload' asset. Since the
        // upload never completed, there is no corresponding file in cloud
        // storage to delete.
        await mediaAssetRepository.delete(id: asset.id);
      }
      _log.info(
        'Successfully deleted ${orphanedAssets.length} orphaned assets.',
      );
    }
  } catch (e, s) {
    _log.severe('An error occurred during the media cleanup process.', e, s);
    exit(1);
  } finally {
    await AppDependencies.instance.dispose();
    exit(0);
  }
}
