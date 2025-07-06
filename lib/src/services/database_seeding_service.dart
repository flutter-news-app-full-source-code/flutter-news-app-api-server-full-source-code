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
      // Manually handle the transaction with BEGIN/COMMIT/ROLLBACK.
      await _connection.execute('BEGIN');

      try {
        _log.fine('Creating "users" table...');
        // All statements are executed on the main connection within the
        // manual transaction.
        await _connection.execute('''
          CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            email TEXT UNIQUE,
            roles JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            last_engagement_shown_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "app_config" table...');
        await _connection.execute('''
          CREATE TABLE IF NOT EXISTS app_config (
            id TEXT PRIMARY KEY,
            user_preference_limits JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "categories" table...');
        await _connection.execute('''
          CREATE TABLE IF NOT EXISTS categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "sources" table...');
        await _connection.execute('''
          CREATE TABLE IF NOT EXISTS sources (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "countries" table...');
        await _connection.execute('''
          CREATE TABLE IF NOT EXISTS countries (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            code TEXT NOT NULL UNIQUE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "headlines" table...');
        await _connection.execute('''
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
        await _connection.execute('''
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
        await _connection.execute('''
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

        await _connection.execute('COMMIT');
      } catch (e) {
        // If any query inside the transaction fails, roll back.
        await _connection.execute('ROLLBACK');
        rethrow; // Re-throw the original error
      }
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

  /// Seeds the database with global fixture data (categories, sources, etc.).
  ///
  /// This method is idempotent, using `ON CONFLICT DO NOTHING` to prevent
  /// errors if the data already exists. It runs within a single transaction.
  Future<void> seedGlobalFixtureData() async {
    _log.info('Seeding global fixture data...');
    try {
      await _connection.execute('BEGIN');
      try {
        // Seed Categories
        _log.fine('Seeding categories...');
        for (final data in categoriesFixturesData) {
          final category = Category.fromJson(data);
          await _connection.execute(
            Sql.named(
              'INSERT INTO categories (id, name) VALUES (@id, @name) '
              'ON CONFLICT (id) DO NOTHING',
            ),
            parameters: category.toJson(),
          );
        }

        // Seed Sources
        _log.fine('Seeding sources...');
        for (final data in sourcesFixturesData) {
          final source = Source.fromJson(data);
          await _connection.execute(
            Sql.named(
              'INSERT INTO sources (id, name) VALUES (@id, @name) '
              'ON CONFLICT (id) DO NOTHING',
            ),
            parameters: source.toJson(),
          );
        }

        // Seed Countries
        _log.fine('Seeding countries...');
        for (final data in countriesFixturesData) {
          final country = Country.fromJson(data);
          await _connection.execute(
            Sql.named(
              'INSERT INTO countries (id, name, code) '
              'VALUES (@id, @name, @code) ON CONFLICT (id) DO NOTHING',
            ),
            parameters: country.toJson(),
          );
        }

        // Seed Headlines
        _log.fine('Seeding headlines...');
        for (final data in headlinesFixturesData) {
          final headline = Headline.fromJson(data);
          await _connection.execute(
            Sql.named(
              'INSERT INTO headlines (id, title, source_id, category_id, '
              'image_url, url, published_at, description, content) '
              'VALUES (@id, @title, @sourceId, @categoryId, @imageUrl, @url, '
              '@publishedAt, @description, @content) '
              'ON CONFLICT (id) DO NOTHING',
            ),
            parameters: headline.toJson(),
          );
        }

        await _connection.execute('COMMIT');
        _log.info('Global fixture data seeding completed successfully.');
      } catch (e) {
        await _connection.execute('ROLLBACK');
        rethrow;
      }
    } on Object catch (e, st) {
      _log.severe(
        'An error occurred during global fixture data seeding.',
        e,
        st,
      );
      throw OperationFailedException(
        'Failed to seed global fixture data: $e',
      );
    }
  }

  /// Seeds the database with the initial AppConfig and the default admin user.
  ///
  /// This method is idempotent, using `ON CONFLICT DO NOTHING` to prevent
  /// errors if the data already exists. It runs within a single transaction.
  Future<void> seedInitialAdminAndConfig() async {
    _log.info('Seeding initial AppConfig and admin user...');
    try {
      await _connection.execute('BEGIN');
      try {
        // Seed AppConfig
        _log.fine('Seeding AppConfig...');
        final appConfig = AppConfig.fromJson(appConfigFixtureData);
        await _connection.execute(
          Sql.named(
            'INSERT INTO app_config (id, user_preference_limits) '
            'VALUES (@id, @user_preference_limits) '
            'ON CONFLICT (id) DO NOTHING',
          ),
          parameters: appConfig.toJson(),
        );

        // Seed Admin User
        _log.fine('Seeding admin user...');
        // Find the admin user in the fixture data.
        final adminUserData = usersFixturesData.firstWhere(
          (user) => (user['roles'] as List).contains(UserRoles.admin),
          orElse: () => throw StateError('Admin user not found in fixtures.'),
        );
        final adminUser = User.fromJson(adminUserData);
        await _connection.execute(
          Sql.named(
            'INSERT INTO users (id, email, roles) '
            'VALUES (@id, @email, @roles) '
            'ON CONFLICT (id) DO NOTHING',
          ),
          parameters: adminUser.toJson(),
        );

        await _connection.execute('COMMIT');
        _log.info(
          'Initial AppConfig and admin user seeding completed successfully.',
        );
      } catch (e) {
        await _connection.execute('ROLLBACK');
        rethrow;
      }
    } on Object catch (e, st) {
      _log.severe(
        'An error occurred during initial admin/config seeding.',
        e,
        st,
      );
      throw OperationFailedException(
        'Failed to seed initial admin/config data: $e',
      );
    }
  }
}
