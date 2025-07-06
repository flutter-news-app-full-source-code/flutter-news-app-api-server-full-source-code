import 'dart:io';

/// {@template environment_config}
/// A utility class for accessing environment variables.
///
/// This class provides a centralized way to read configuration values
/// from the environment, ensuring that critical settings like database
/// connection strings are managed outside of the source code.
/// {@endtemplate}
abstract final class EnvironmentConfig {
  /// Retrieves the PostgreSQL database connection URI from the environment.
  ///
  /// The value is read from the `DATABASE_URL` environment variable.
  ///
  /// Throws a [StateError] if the `DATABASE_URL` environment variable is not
  /// set, as the application cannot function without it.
  static String get databaseUrl {
    final dbUrl = Platform.environment['DATABASE_URL'];
    if (dbUrl == null || dbUrl.isEmpty) {
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
  static String get environment => Platform.environment['ENV'] ?? 'production';
}
