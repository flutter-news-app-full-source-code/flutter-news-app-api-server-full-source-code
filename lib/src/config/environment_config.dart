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
    final env = DotEnv(includePlatformEnvironment: true); // Start with default
    var currentDir = Directory.current;
    _log.fine('Starting .env search from: ${currentDir.path}');
    // Traverse up the directory tree to find pubspec.yaml
    while (currentDir.parent.path != currentDir.path) {
      final pubspecPath =
          '${currentDir.path}${Platform.pathSeparator}pubspec.yaml';
      _log.finer('Checking for pubspec.yaml at: $pubspecPath');
      if (File(pubspecPath).existsSync()) {
        // Found pubspec.yaml, now load .env from the same directory
        final envPath = '${currentDir.path}${Platform.pathSeparator}.env';
        _log.info(
          'Found pubspec.yaml, now looking for .env at: ${currentDir.path}',
        );
        if (File(envPath).existsSync()) {
          _log.info('Found .env file at: $envPath');
          env.load([envPath]); // Load variables from the found .env file
          return env; // Return immediately upon finding
        } else {
          _log.warning('pubspec.yaml found, but no .env in the same directory.');
          break; // Stop searching since pubspec.yaml should contain .env
        }
      }
      currentDir = currentDir.parent; // Move to the parent directory
      _log.finer('Moving up to parent directory: ${currentDir.path}');
    }
    // If loop completes without returning, .env was not found
    _log.warning('.env not found by searching. Falling back to default load().');
    env.load(); // Fallback to default load
    return env; // Return even if fallback
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

  /// Retrieves the allowed CORS origin from the environment.
  ///
  /// The value is read from the `CORS_ALLOWED_ORIGIN` environment variable.
  /// This is used to configure CORS for production environments.
  /// Returns `null` if the variable is not set.
  static String? get corsAllowedOrigin => _env['CORS_ALLOWED_ORIGIN'];
}
