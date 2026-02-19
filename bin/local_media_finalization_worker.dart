import 'dart:async';

import 'package:flutter_news_app_api_server_full_source_code/src/config/app_dependencies.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/storage/local_media_finalization_job.dart';
import 'package:logging/logging.dart';

final _log = Logger('LocalMediaFinalizationWorker');

/// The main entry point for the standalone Local Media Finalization Worker.
///
/// This worker polls the `local_media_finalization_jobs` collection for new
/// jobs created by the `upload-local` endpoint. It processes these jobs
/// asynchronously, making the local storage provider architecturally consistent
/// with the webhook-based cloud providers.
///
/// ### Operational Guidelines
///
/// **Resource Intensity:** Low (I/O Bound)
/// - This worker performs fast, indexed database queries and updates. It is
///   designed to be lightweight.
///
/// **Recommended Schedule:**
/// - Run this worker as a long-running background process (e.g., via a
///   `systemd` service or in a separate Docker container).
/// - The polling interval is configured internally.
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
  final deps = AppDependencies.instance;

  final finalizationJobService = deps.finalizationJobService;

  _log.info('Starting local media finalization worker...');

  // Use a periodic timer to poll for jobs.
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    _log.finer('Polling for new finalization jobs...');
    LocalMediaFinalizationJob? job;
    try {
      // Atomically find one pending job and remove it.
      // Sort by creation time to process oldest jobs first.
      job = await finalizationJobService.claimJob();

      if (job == null) {
        return; // No job to process, wait for next poll.
      }

      final mediaAsset = await deps.mediaAssetRepository.read(
        id: job.mediaAssetId,
      );

      await deps.mediaService.finalizeUpload(
        mediaAsset: mediaAsset,
        publicUrl: job.publicUrl,
      );

      _log.info('Successfully finalized asset ${mediaAsset.id}.');
    } catch (e, s) {
      _log.severe('Error processing finalization job.', e, s);
      if (job != null) {
        _log.severe('Job data for failed process: ${job.toJson()}');
      }
    }
  });
}
