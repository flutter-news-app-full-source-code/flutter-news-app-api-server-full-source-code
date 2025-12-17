import 'dart:io';

import 'package:flutter_news_app_api_server_full_source_code/src/config/app_dependencies.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/analytics/analytics.dart';
import 'package:logging/logging.dart';

/// The main entry point for the standalone Analytics Sync Worker process.
///
/// This script initializes application dependencies, retrieves the
/// [AnalyticsSyncService], and executes its `run()` method to perform the
/// periodic data synchronization.
///
/// This executable can be compiled into a native binary and run by a scheduler
/// (e.g., a cron job) to automate the analytics data pipeline.
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
  await AppDependencies.instance.analyticsSyncService!.run();
  await AppDependencies.instance.dispose();
  exit(0);
}
