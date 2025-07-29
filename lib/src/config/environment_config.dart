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
          _log.warning(
            'pubspec.yaml found, but no .env in the same directory.',
          );
          break; // Stop searching since pubspec.yaml should contain .env
        }
      }
      currentDir = currentDir.parent; // Move to the parent directory
      _log.finer('Moving up to parent directory: ${currentDir.path}');
    }
    // If loop completes without returning, .env was not found
    _log.warning(
      '.env not found by searching. Falling back to default load().',
    );
    env.load(); // Fallback to default load
    return env; // Return even if fallback
  }

  static String _getRequiredEnv(String key) {
    final value = _env[key];
    if (value == null || value.isEmpty) {
      _log.severe('$key not found in environment variables.');
      throw StateError('FATAL: $key environment variable is not set.');
    }
    return value;
  }

  /// Retrieves the database connection URI from the environment.
  ///
  /// The value is read from the `DATABASE_URL` environment variable.
  ///
  /// Throws a [StateError] if the `DATABASE_URL` environment variable is not
  /// set, as the application cannot function without it.
  static String get databaseUrl => _getRequiredEnv('DATABASE_URL');

  /// Retrieves the JWT secret key from the environment.
  ///
  /// The value is read from the `JWT_SECRET_KEY` environment variable.
  ///
  /// Throws a [StateError] if the `JWT_SECRET_KEY` environment variable is not
  /// set, as the application cannot function without it.
  static String get jwtSecretKey => _getRequiredEnv('JWT_SECRET_KEY');

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

  /// Retrieves the JWT issuer URL from the environment.
  ///
  /// The value is read from the `JWT_ISSUER` environment variable.
  /// Defaults to 'http://localhost:8080' if not set.
  static String get jwtIssuer => _env['JWT_ISSUER'] ?? 'http://localhost:8080';

  /// Retrieves the JWT expiry duration in hours from the environment.
  ///
  /// The value is read from the `JWT_EXPIRY_HOURS` environment variable.
  /// Defaults to 1 hour if not set or if parsing fails.
  static Duration get jwtExpiryDuration {
    final hours = int.tryParse(_env['JWT_EXPIRY_HOURS'] ?? '1');
    return Duration(hours: hours ?? 1);
  }

  /// Retrieves the SendGrid API key from the environment.
  ///
  /// Throws a [StateError] if the `SENDGRID_API_KEY` is not set.
  static String get sendGridApiKey => _getRequiredEnv('SENDGRID_API_KEY');

  /// Retrieves the default sender email from the environment.
  ///
  /// Throws a [StateError] if the `DEFAULT_SENDER_EMAIL` is not set.
  static String get defaultSenderEmail =>
      _getRequiredEnv('DEFAULT_SENDER_EMAIL');

  /// Retrieves the SendGrid OTP template ID from the environment.
  ///
  /// Throws a [StateError] if the `OTP_TEMPLATE_ID` is not set.
  static String get otpTemplateId => _getRequiredEnv('OTP_TEMPLATE_ID');

  /// Retrieves the SendGrid API URL from the environment, if provided.
  ///
  /// Returns `null` if the `SENDGRID_API_URL` is not set.
  static String? get sendGridApiUrl => _env['SENDGRID_API_URL'];

  /// Retrieves the override admin email from the environment, if provided.
  ///
  /// This is used to set or replace the single administrator account on startup.
  /// Returns `null` if the `OVERRIDE_ADMIN_EMAIL` is not set.
  static String? get overrideAdminEmail => _env['OVERRIDE_ADMIN_EMAIL'];

  /// Retrieves the request limit for the request-code endpoint.
  ///
  /// Defaults to 3 if not set or if parsing fails.
  static int get rateLimitRequestCodeLimit {
    return int.tryParse(_env['RATE_LIMIT_REQUEST_CODE_LIMIT'] ?? '3') ?? 3;
  }

  /// Retrieves the time window for the request-code endpoint rate limit.
  ///
  /// Defaults to 24 hours if not set or if parsing fails.
  static Duration get rateLimitRequestCodeWindow {
    final hours =
        int.tryParse(_env['RATE_LIMIT_REQUEST_CODE_WINDOW_HOURS'] ?? '24') ??
            24;
    return Duration(hours: hours);
  }

  /// Retrieves the request limit for the data API endpoints.
  ///
  /// Defaults to 1000 if not set or if parsing fails.
  static int get rateLimitDataApiLimit {
    return int.tryParse(_env['RATE_LIMIT_DATA_API_LIMIT'] ?? '1000') ?? 1000;
  }

  /// Retrieves the time window for the data API rate limit.
  ///
  /// Defaults to 60 minutes if not set or if parsing fails.
  static Duration get rateLimitDataApiWindow {
    final minutes =
        int.tryParse(_env['RATE_LIMIT_DATA_API_WINDOW_MINUTES'] ?? '60') ?? 60;
    return Duration(minutes: minutes);
  }
}
