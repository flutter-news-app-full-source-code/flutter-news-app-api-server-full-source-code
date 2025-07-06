import 'dart:io';
import 'package:logging/logging.dart';
import 'package:dotenv/dotenv.dart';

/// {@template environment_config}
/// A utility class for accessing environment variables.
///
/// This class provides a centralized way to read configuration values
/// from the environment, ensuring that critical settings like database
/// connection strings are managed outside of the source code.
/// {@endtemplate}
abstract final class EnvironmentConfig {
  static final _log = Logger('EnvironmentConfig');

  // The DotEnv instance that loads the .env file and platform variables.
  // It's initialized once and reused.
  static final _env = DotEnv(includePlatformEnvironment: true)..load();

  /// Retrieves the PostgreSQL database connection URI from the environment.
  ///
  /// The value is read from the `DATABASE_URL` environment variable.
  ///
  /// Throws a [StateError] if the `DATABASE_URL` environment variable is not
  /// set, as the application cannot function without it.
  static String get databaseUrl {
    final dbUrl = _env['DATABASE_URL'];
    if (dbUrl == null || dbUrl.isEmpty) {
      _log.severe(
        'DATABASE_URL not found. Dumping available environment variables:',
      );
      _env.map.forEach((key, value) {
        _log.severe('  - $key: $value');
      });
      throw StateError(
        'FATAL: DATABASE_URL environment variable is not set. '
        'The application cannot start without a database connection.',
      );
    }
    return dbUrl;
  }

  /// Retrieves the current environment mode (e.g., 'development', 'production').
  ///
  /// The value is read from the `ENV` environment variable.
  /// Defaults to 'production' if the variable is not set.
  static String get environment => _env['ENV'] ?? 'production';
}
