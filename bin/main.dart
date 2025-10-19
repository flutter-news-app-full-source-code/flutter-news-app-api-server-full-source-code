// ignore_for_file: avoid_print

import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/app_dependencies.dart';
import 'package:logging/logging.dart';
import 'package:shelf_hotreload/shelf_hotreload.dart';

// Import the generated server entrypoint from the .dart_frog directory.
// This file contains the `createServer` function we need.
// We use a prefix to avoid a name collision with our own `main` function.
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
/// "fail-fast" approach that is compatible with Dart Frog's hot reload.
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

  // This is our custom hot-reload-aware startup logic.
  // The `withHotreload` function from `shelf_hotreload` (used by Dart Frog)
  // takes a builder function that it calls whenever a reload is needed.
  // We place our initialization logic inside this builder.
  withHotreload(
    () async {
      try {
        log.info('EAGER_INIT: Initializing application dependencies...');

        // Eagerly initialize all dependencies. If this fails, it will throw.
        await AppDependencies.instance.init();

        log.info('EAGER_INIT: Dependencies initialized successfully.');
        log.info('EAGER_INIT: Starting Dart Frog server...');

        // Use the generated `createServer` function from Dart Frog.
        final address = InternetAddress.anyIPv6;
        const port = 8080;
        return serve(server.buildRootHandler(), address, port);
      } catch (e, s) {
        log.severe('EAGER_INIT: FATAL: Failed to start server.', e, s);
        // Exit the process if initialization fails.
        exit(1);
      }
    },
  );
}
