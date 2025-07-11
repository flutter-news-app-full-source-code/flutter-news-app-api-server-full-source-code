import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';

/// {@template environment_config}
/// A utility class for accessing environment variables.
///
/// This class provides a centralized way to read configuration values
/// from the environment, ensuring that critical settings like database
/// connection strings are managed outside of the source code.
/// {@endtemplate}
abstract final class EnvironmentConfig {
  static final _log = Logger('EnvironmentConfig');

  // The DotEnv instance is now loaded via a helper method to make it more
  // resilient to current working directory issues.
  static final _env = _loadEnv();

  /// Helper method to load the .env file more robustly.
  ///
  /// It searches for the .env file starting from the current directory
  /// and moving up to parent directories. This makes it resilient to
  /// issues where the execution context's working directory is not the
  /// project root.
  static DotEnv _loadEnv() {
    final env = DotEnv(includePlatformEnvironment: true);
    try {
      // Find the project root by looking for pubspec.yaml, then find .env
      var dir = Directory.current;
      while (true) {
        final pubspecFile = File('${dir.path}/pubspec.yaml');
        if (pubspecFile.existsSync()) {
          // Found project root, now look for .env in this directory
          final envFile = File('${dir.path}/.env');
          if (envFile.existsSync()) {
            _log.info('Found .env file at: ${envFile.path}');
            env.load([envFile.path]);
            return env;
          }
          break; // Found pubspec but no .env, break and fall back
        }

        // Stop if we have reached the root of the filesystem.
        if (dir.parent.path == dir.path) {
          break;
        }
        dir = dir.parent;
      }
    } catch (e) {
      _log.warning('Error during robust .env search: $e. Falling back.');
    }

    // Fallback for when the robust search fails
    _log.warning(
      '.env file not found by searching for project root. '
      'Falling back to default load().',
    );
    env.load();
    return env;
  }

  /// Retrieves the database connection URI from the environment.
  ///
  /// The value is read from the `DATABASE_URL` environment variable.
  ///
  /// Throws a [StateError] if the `DATABASE_URL` environment variable is not
  /// set, as the application cannot function without it.
  static String get databaseUrl {
    final dbUrl = _env['DATABASE_URL'];
    if (dbUrl == null || dbUrl.isEmpty) {
      _log.severe('DATABASE_URL not found in environment variables.');
      throw StateError(
        'FATAL: DATABASE_URL environment variable is not set. '
        'The application cannot start without a database connection.',
      );
    }
    return dbUrl;
  }

  /// Retrieves the current environment mode (e.g., 'development').
  ///
  /// The value is read from the `ENV` environment variable.
  /// Defaults to 'production' if the variable is not set.
  static String get environment => _env['ENV'] ?? 'production';
}
