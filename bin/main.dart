// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/app_dependencies.dart';
import 'package:logging/logging.dart';

// Import the generated server entrypoint to access `buildRootHandler`.
import '../.dart_frog/server.dart' as server;

/// The main entrypoint for the application.
///
/// This custom entrypoint implements an "eager loading" strategy. It ensures
/// that all critical application dependencies are initialized *before* the
/// HTTP server starts listening for requests.
///
/// If any part of the dependency initialization fails (e.g., database
/// connection, migrations), the process will log a fatal error and exit,
/// preventing the server from running in a broken state. This is a robust,
/// "fail-fast" approach.
Future<void> main(List<String> args) async {
  // Use a local logger for startup-specific messages.
  // This is also the ideal place to configure the root logger for the entire
  // application, as it's guaranteed to run only once at startup.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // A more detailed logger that includes the error and stack trace.
    print(
      '${record.level.name}: ${record.time}: ${record.loggerName}: '
      '${record.message}',
    );
    if (record.error != null) {
      print('  ERROR: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('  STACK TRACE: ${record.stackTrace}');
    }
  });

  final log = Logger('EagerEntrypoint');

  try {
    log.info('EAGER_INIT: Initializing application dependencies...');

    // Eagerly initialize all dependencies. If this fails, it will throw.
    await AppDependencies.instance.init();

    log.info('EAGER_INIT: Dependencies initialized successfully.');
    log.info('EAGER_INIT: Starting Dart Frog server...');

    // Start the server directly without the hot reload wrapper.
    final address = InternetAddress.anyIPv6;
    final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
    await serve(server.buildRootHandler(), address, port);
  } catch (e, s) {
    log.severe('EAGER_INIT: FATAL: Failed to start server.', e, s);
    // Exit the process if initialization fails.
    exit(1);
  }
}
