import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:verity_api/src/config/app_dependencies.dart';

/// Standalone entry point for the News Ingestion Worker.
///
/// This worker is designed to be invoked by a system-level Cron job.
/// It bootstraps the production environment, executes the ingestion
/// cycle for all due Aggregator tasks, and exits.
Future<void> main(List<String> args) async {
  // 1. Configure Logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print(
      '${record.level.name}: ${record.time}: ${record.loggerName}: '
      '${record.message}',
    );
    if (record.error != null) {
      // ignore: avoid_print
      print('  ERROR: ${record.error}');
    }
  });

  final log = Logger('NewsIngestionWorker');
  log.info('Worker process started.');

  // Safety Valve: Hard kill after 5 minutes to prevent zombie processes.
  final watchdog = Timer(const Duration(minutes: 5), () {
    log.severe('Worker timed out after 5 minutes. Forcing exit.');
    exit(1);
  });

  var exitCode = 0;

  try {
    // 2. Initialize Production Dependencies
    // This connects to MongoDB and sets up Repositories.
    await AppDependencies.instance.init();
    log.info('Dependencies initialized.');

    // 3. Execute Ingestion
    // We access the service through the singleton instance.
    final ingestionService = AppDependencies.instance.newsIngestionService;
    await ingestionService.run();

    log.info('Ingestion cycle completed successfully.');

    // If we get here, the work finished successfully. Cancel the watchdog.
    watchdog.cancel();
  } catch (e, s) {
    watchdog.cancel(); // Cancel watchdog to allow immediate exit
    log.severe('Fatal error in worker process.', e, s);
    exitCode = 1;
  } finally {
    // 4. Graceful Shutdown
    await AppDependencies.instance.dispose();
    log.info('Worker process exiting.');
    exit(exitCode);
  }
}
