import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:veritai_api/src/config/app_dependencies.dart';
import 'package:veritai_api/src/services/intelligence/intelligence.dart'
    show IntelligenceService;

/// Standalone entry point for the Intelligence Worker (Cron B).
///
/// This binary initializes the application dependencies and triggers the
/// [IntelligenceService] to process pending draft headlines.
Future<void> main(List<String> args) async {
  // 1. Configure Logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print(
      '${record.level.name}: ${record.time}: [IntelligenceWorker] '
      '${record.message}',
    );
    if (record.error != null) {
      // ignore: avoid_print
      print('  ERROR: ${record.error}');
    }
  });

  final log = Logger('IntelligenceWorkerMain');
  log.info('Intelligence worker process started.');

  // Safety Valve: Hard kill after 10 minutes to prevent zombie processes.
  final watchdog = Timer(const Duration(minutes: 10), () {
    log.severe('Worker timed out after 10 minutes. Forcing exit.');
    exit(1);
  });

  var exitCode = 0;

  try {
    // 2. Initialize Dependencies
    await AppDependencies.instance.init();
    log.info('Dependencies initialized.');

    // 3. Run Worker
    final intelligenceService = AppDependencies.instance.intelligenceService;
    await intelligenceService.run();

    // If we get here, the work finished successfully. Cancel the watchdog.
    watchdog.cancel();
  } catch (e, s) {
    watchdog.cancel(); // Cancel watchdog to allow immediate exit
    log.severe('Fatal error in intelligence worker.', e, s);
    exitCode = 1;
  } finally {
    await AppDependencies.instance.dispose();
    exit(exitCode);
  }
}
