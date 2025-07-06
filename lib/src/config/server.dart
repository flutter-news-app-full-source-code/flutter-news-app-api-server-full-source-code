import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/config/environment_config.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

/// Global logger instance.
final _log = Logger('ht_api');

/// Global PostgreSQL connection instance.
late final Connection _connection;

/// The main entry point for the server.
///
/// This function is responsible for:
/// 1. Setting up the global logger.
/// 2. Establishing the PostgreSQL database connection.
/// 3. Providing these dependencies to the Dart Frog handler.
/// 4. Gracefully closing the database connection on server shutdown.
Future<HttpServer> run(Handler handler, InternetAddress ip, int port) async {
  // 1. Setup Logger
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print(
      '${record.level.name}: ${record.time}: '
      '${record.loggerName}: ${record.message}',
    );
  });

  // 2. Establish Database Connection
  _log.info('Connecting to PostgreSQL database...');
  _connection = await Connection.open(
    Endpoint.uri(Uri.parse(EnvironmentConfig.databaseUrl)),
    settings: const ConnectionSettings(sslMode: SslMode.prefer),
  );
  _log.info('PostgreSQL database connection established.');

  // 3. Start the server and set up shutdown logic
  return serve(
    handler,
    ip,
    port,
    onShutdown: () async {
      _log.info('Server shutting down. Closing database connection...');
      await _connection.close();
      _log.info('Database connection closed.');
    },
  );
}