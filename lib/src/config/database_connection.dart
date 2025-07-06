import 'dart:async';

import 'package:ht_api/src/config/environment_config.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

/// A singleton class to manage a single, shared PostgreSQL database connection.
///
/// This pattern ensures that the application establishes a connection to the
/// database only once and reuses it for all subsequent operations, which is
/// crucial for performance and resource management.
class DatabaseConnectionManager {
  // Private constructor for the singleton pattern.
  DatabaseConnectionManager._();

  /// The single, global instance of the [DatabaseConnectionManager].
  static final instance = DatabaseConnectionManager._();

  final _log = Logger('DatabaseConnectionManager');

  // A completer to signal when the database connection is established.
  final _completer = Completer<Connection>();

  /// Returns a future that completes with the established database connection.
  ///
  /// If the connection has not been initialized yet, it calls `init()` to
  /// establish it. Subsequent calls will return the same connection future.
  Future<Connection> get connection => _completer.future;

  /// Initializes the database connection.
  ///
  /// This method is idempotent. It parses the database URL from the
  /// environment, opens a connection to the PostgreSQL server, and completes
  /// the `_completer` with the connection. It only performs the connection
  /// logic on the very first call.
  Future<void> init() async {
    if (_completer.isCompleted) {
      _log.fine('Database connection already initializing/initialized.');
      return;
    }

    _log.info('Initializing database connection...');
    final dbUri = Uri.parse(EnvironmentConfig.databaseUrl);
    String? username;
    String? password;
    if (dbUri.userInfo.isNotEmpty) {
      final parts = dbUri.userInfo.split(':');
      username = Uri.decodeComponent(parts.first);
      if (parts.length > 1) {
        password = Uri.decodeComponent(parts.last);
      }
    }

    final connection = await Connection.open(
      Endpoint(
        host: dbUri.host,
        port: dbUri.port,
        database: dbUri.path.substring(1),
        username: username,
        password: password,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.require),
    );
    _log.info('Database connection established successfully.');
    _completer.complete(connection);
  }
}
