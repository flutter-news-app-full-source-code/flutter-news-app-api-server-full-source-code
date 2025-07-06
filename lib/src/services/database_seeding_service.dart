import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:ht_shared/ht_shared.dart';

/// {@template database_seeding_service}
/// A service responsible for initializing the database schema and seeding it
/// with initial data.
///
/// This service is intended to be run at application startup, particularly
/// in development environments or during the first run of a production instance
/// to set up the initial admin user and default configuration.
/// {@endtemplate}
class DatabaseSeedingService {
  /// {@macro database_seeding_service}
  const DatabaseSeedingService({
    required Connection connection,
    required Logger log,
  }) : _connection = connection,
       _log = log;

  final Connection _connection;
  final Logger _log;

  /// Creates all necessary tables in the database if they do not already exist.
  ///
  /// This method executes a series of `CREATE TABLE IF NOT EXISTS` statements
  /// within a single transaction to ensure atomicity.
  Future<void> createTables() async {
    _log.info('Starting database schema creation...');
    try {
      await _connection.transaction((ctx) async {
        _log.fine('Creating "users" table...');
        await ctx.execute('''
          CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            email TEXT UNIQUE,
            roles JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            last_engagement_shown_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "app_config" table...');
        await ctx.execute('''
          CREATE TABLE IF NOT EXISTS app_config (
            id TEXT PRIMARY KEY,
            user_preference_limits JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "categories" table...');
        await ctx.execute('''
          CREATE TABLE IF NOT EXISTS categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "sources" table...');
        await ctx.execute('''
          CREATE TABLE IF NOT EXISTS sources (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "countries" table...');
        await ctx.execute('''
          CREATE TABLE IF NOT EXISTS countries (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            code TEXT NOT NULL UNIQUE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "headlines" table...');
        await ctx.execute('''
          CREATE TABLE IF NOT EXISTS headlines (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            source_id TEXT NOT NULL,
            category_id TEXT NOT NULL,
            image_url TEXT NOT NULL,
            url TEXT NOT NULL,
            published_at TIMESTAMPTZ NOT NULL,
            description TEXT,
            content TEXT,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "user_app_settings" table...');
        await ctx.execute('''
          CREATE TABLE IF NOT EXISTS user_app_settings (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            display_settings JSONB NOT NULL,
            language JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "user_content_preferences" table...');
        await ctx.execute('''
          CREATE TABLE IF NOT EXISTS user_content_preferences (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            followed_categories JSONB NOT NULL,
            followed_sources JSONB NOT NULL,
            followed_countries JSONB NOT NULL,
            saved_headlines JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');
      });
      _log.info('Database schema creation completed successfully.');
    } on Object catch (e, st) {
      _log.severe(
        'An error occurred during database schema creation.',
        e,
        st,
      );
      // Propagate as a standard exception for the server to handle.
      throw OperationFailedException(
        'Failed to initialize database schema: $e',
      );
    }
  }
}
