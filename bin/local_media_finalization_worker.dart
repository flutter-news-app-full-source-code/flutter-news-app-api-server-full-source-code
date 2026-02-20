import 'dart:async';
import 'dart:io';

import 'package:flutter_news_app_api_server_full_source_code/src/config/app_dependencies.dart';
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
/// - Run this worker frequently to ensure timely processing of local media
///   uploads. A cron job executing every 2 minute is a reasonable starting point.
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

  _log.info('Starting local media finalization worker...');

  try {
    final deps = AppDependencies.instance;
    final finalizationJobService = deps.finalizationJobService;

    // Loop to process jobs in batches until the queue is empty.
    while (true) {
      _log.info('Polling for new finalization jobs...');
      final jobs = await finalizationJobService.claimJobsInBatch(batchSize: 20);

      if (jobs.isEmpty) {
        _log.info('No more jobs to process. Worker will exit.');
        break; // Exit the loop if no jobs are found.
      }

      _log.info('Processing a batch of ${jobs.length} finalization jobs.');

      // Process all claimed jobs concurrently.
      final processingFutures = jobs.map((job) async {
        // Individual try-catch to prevent one failed job from stopping others.
        try {
          final mediaAsset = await deps.mediaAssetRepository.read(
            id: job.mediaAssetId,
          );
          await deps.mediaService.finalizeUpload(
            mediaAsset: mediaAsset,
            publicUrl: job.publicUrl,
          );
          _log.info(
            'Successfully finalized asset ${mediaAsset.id} for job ${job.id}.',
          );
        } catch (e, s) {
          _log.severe('Error processing job ${job.id}.', e, s);
          // Optionally, mark the job as failed here if needed.
        }
      });

      await Future.wait(processingFutures);
    }
    _log.info('Local media finalization worker finished successfully.');
  } catch (e, s) {
    _log.severe('An error occurred during the finalization process.', e, s);
    exit(1);
  } finally {
    await AppDependencies.instance.dispose();
    exit(0);
  }
}
