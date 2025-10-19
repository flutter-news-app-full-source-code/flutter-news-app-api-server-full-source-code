// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter_news_app_api_server_full_source_code/src/config/app_dependencies.dart';
import 'package:logging/logging.dart';

// Import the generated server entrypoint from the .dart_frog directory.
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
/// "fail-fast" approach suitable for production environments.
Future<void> main(List<String> args) async {
  // Use a local logger for startup-specific messages.
  final log = Logger('EagerEntrypoint');

  try {
    log.info('EAGER_INIT: Initializing application dependencies...');

    // Eagerly initialize all dependencies. If this fails, it will throw.
    await AppDependencies.instance.init();

    log.info('EAGER_INIT: Dependencies initialized successfully.');
    log.info('EAGER_INIT: Starting Dart Frog server...');

    // Only if initialization succeeds, start the Dart Frog server.
    await server.main();
  } catch (e, s) {
    log.severe('EAGER_INIT: FATAL: Failed to start server.', e, s);
    exit(1); // Exit with a non-zero code to indicate failure.
  }
}
