import 'dart:convert';
import 'package:ht_shared/ht_shared.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

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
            email TEXT NOT NULL UNIQUE,
            app_role TEXT NOT NULL,
            dashboard_role TEXT NOT NULL,
            feed_action_status JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
          );
        ''');

        _log.fine('Creating "remote_config" table...');
        await _connection.execute('''
          CREATE TABLE IF NOT EXISTS remote_config (
            id TEXT PRIMARY KEY,
            user_preference_config JSONB NOT NULL,
            ad_config JSONB NOT NULL,
            account_action_config JSONB NOT NULL,
            app_status JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "topics" table...');
        await _connection.execute('''
          CREATE TABLE IF NOT EXISTS topics (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            icon_url TEXT,
            status TEXT,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "sources" table...');
        await _connection.execute('''
          CREATE TABLE IF NOT EXISTS sources (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            url TEXT,
            language TEXT,
            status TEXT,
            source_type TEXT,
            headquarters_country_id TEXT REFERENCES countries(id),
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "countries" table...');
        await _connection.execute('''
          CREATE TABLE IF NOT EXISTS countries (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            iso_code TEXT NOT NULL UNIQUE,
            flag_url TEXT NOT NULL,
            status TEXT,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "headlines" table...');
        await _connection.execute('''
          CREATE TABLE IF NOT EXISTS headlines (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            excerpt TEXT,
            url TEXT,
            image_url TEXT,
            source_id TEXT REFERENCES sources(id),
            topic_id TEXT REFERENCES topics(id),
            event_country_id TEXT REFERENCES countries(id),
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ,
            status TEXT,
          );
        ''');

        _log.fine('Creating "user_app_settings" table...');
        await _connection.execute('''
          CREATE TABLE IF NOT EXISTS user_app_settings (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            display_settings JSONB NOT NULL, -- Nested object, stored as JSON
            language TEXT NOT NULL, -- Simple string, stored as TEXT
            feed_preferences JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ
          );
        ''');

        _log.fine('Creating "user_content_preferences" table...');
        await _connection.execute('''
          CREATE TABLE IF NOT EXISTS user_content_preferences (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            followed_topics JSONB NOT NULL,
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
      _log.severe('An error occurred during database schema creation.', e, st);
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
        // Seed Topics
        _log.fine('Seeding topics...');
        for (final topic in topicsFixturesData) {
          final params = topic.toJson()
            ..putIfAbsent('description', () => null)
            ..putIfAbsent('icon_url', () => null)
            ..putIfAbsent('updated_at', () => null);

          await _connection.execute(
            Sql.named(
              'INSERT INTO topics (id, name, description, icon_url, '
              'status, created_at, updated_at) VALUES (@id, @name, '
              '@description, @icon_url, @status, @created_at, @updated_at) '
              'ON CONFLICT (id) DO NOTHING',
            ),
            parameters: params,
          );
        }

        // Seed Countries (must be done before sources and headlines)
        _log.fine('Seeding countries...');
        for (final country in countriesFixturesData) {
          final params = country.toJson()
            ..putIfAbsent('updated_at', () => null);

          await _connection.execute(
            Sql.named(
              'INSERT INTO countries (id, name, iso_code, flag_url, '
              'status, created_at, updated_at) VALUES (@id, @name, '
              '@iso_code, @flag_url, @status, @created_at, @updated_at) '
              'ON CONFLICT (id) DO NOTHING',
            ),
            parameters: params,
          );
        }

        // Seed Sources
        _log.fine('Seeding sources...');
        for (final source in sourcesFixturesData) {
          final params = source.toJson()
            // The `headquarters` field in the model is a nested `Country`
            // object. We extract its ID to store in the
            // `headquarters_country_id` column and then remove the original
            // nested object from the parameters to avoid a "superfluous
            // variable" error.
            ..['headquarters_country_id'] = source.headquarters.id
            ..remove('headquarters')
            ..putIfAbsent('description', () => null)
            ..putIfAbsent('url', () => null)
            ..putIfAbsent('language', () => null)
            ..putIfAbsent('source_type', () => null)
            ..putIfAbsent('updated_at', () => null);

          await _connection.execute(
            Sql.named(
              'INSERT INTO sources (id, name, description, url, language, '
              'status, source_type, headquarters_country_id, '
              'created_at, updated_at) VALUES (@id, @name, @description, @url, '
              '@language, @status, @source_type, '
              '@headquarters_country_id, @created_at, @updated_at) '
              'ON CONFLICT (id) DO NOTHING',
            ),
            parameters: params,
          );
        }

        // Seed Headlines
        _log.fine('Seeding headlines...');
        for (final headline in headlinesFixturesData) {
          final params = headline.toJson()
            ..['source_id'] = headline.source.id
            ..['topic_id'] = headline.topic.id
            ..['event_country_id'] = headline.eventCountry.id
            ..remove('source')
            ..remove('topic')
            ..remove('eventCountry')
            ..putIfAbsent('excerpt', () => null)
            ..putIfAbsent('updated_at', () => null)
            ..putIfAbsent('image_url', () => null)
            ..putIfAbsent('url', () => null);

          await _connection.execute(
            Sql.named(
              'INSERT INTO headlines (id, title, excerpt, url, image_url, '
              'source_id, topic_id, event_country_id, status, created_at, '
              'updated_at) VALUES (@id, @title, @excerpt, @url, @image_url, '
              '@source_id, @topic_id, @event_country_id, @status, @created_at, @updated_at) '
              'ON CONFLICT (id) DO NOTHING',
            ),
            parameters: params,
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
      throw OperationFailedException('Failed to seed global fixture data: $e');
    }
  }

  /// Seeds the database with the initial RemoteConfig and the default admin user.
  ///
  /// This method is idempotent, using `ON CONFLICT DO NOTHING` to prevent
  /// errors if the data already exists. It runs within a single transaction.
  Future<void> seedInitialAdminAndConfig() async {
    _log.info('Seeding initial RemoteConfig and admin user...');
    try {
      await _connection.execute('BEGIN');
      try {
        // Seed RemoteConfig
        _log.fine('Seeding RemoteConfig...');
        const remoteConfig = remoteConfigFixtureData;
        // The `remote_config` table has multiple JSONB columns. We must
        // provide an explicit map with JSON-encoded values to avoid a
        // "superfluous variables" error from the postgres driver.
        await _connection.execute(
          Sql.named(
            'INSERT INTO remote_config (id, user_preference_config, ad_config, '
            'account_action_config, app_status) VALUES (@id, '
            '@user_preference_config, @ad_config, @account_action_config, '
            '@app_status) '
            'ON CONFLICT (id) DO NOTHING',
          ),
          parameters: {
            'id': remoteConfig.id,
            'user_preference_config': jsonEncode(
              remoteConfig.userPreferenceConfig.toJson(),
            ),
            'ad_config': jsonEncode(remoteConfig.adConfig.toJson()),
            'account_action_config': jsonEncode(
              remoteConfig.accountActionConfig.toJson(),
            ),
            'app_status': jsonEncode(remoteConfig.appStatus.toJson()),
          },
        );

        // Seed Admin User
        _log.fine('Seeding admin user...');
        // Find the admin user in the fixture data.
        final adminUser = usersFixturesData.firstWhere(
          (user) => user.dashboardRole == DashboardUserRole.admin,
          orElse: () => throw StateError('Admin user not found in fixtures.'),
        );

        // The `users` table has specific columns for roles and status.
        await _connection.execute(
          Sql.named(
            'INSERT INTO users (id, email, app_role, dashboard_role, '
            'feed_action_status) VALUES (@id, @email, @app_role, '
            '@dashboard_role, @feed_action_status) '
            'ON CONFLICT (id) DO NOTHING',
          ),
          parameters: () {
            final params = adminUser.toJson();
            params['feed_action_status'] = jsonEncode(
              params['feed_action_status'],
            );
            return params;
          }(),
        );

        // Seed default settings and preferences for the admin user.
        final adminSettings = userAppSettingsFixturesData.firstWhere(
          (settings) => settings.id == adminUser.id,
        );
        final adminPreferences = userContentPreferencesFixturesData.firstWhere(
          (prefs) => prefs.id == adminUser.id,
        );

        await _connection.execute(
          Sql.named(
            'INSERT INTO user_app_settings (id, user_id, display_settings, '
            'language, feed_preferences) VALUES (@id, @user_id, '
            '@display_settings, @language, @feed_preferences) '
            'ON CONFLICT (id) DO NOTHING',
          ),
          parameters: () {
            final params = adminSettings.toJson();
            params['user_id'] = adminUser.id;
            params['display_settings'] = jsonEncode(params['display_settings']);
            params['feed_preferences'] = jsonEncode(params['feed_preferences']);
            return params;
          }(),
        );

        await _connection.execute(
          Sql.named(
            'INSERT INTO user_content_preferences (id, user_id, '
            'followed_topics, followed_sources, followed_countries, '
            'saved_headlines) VALUES (@id, @user_id, @followed_topics, '
            '@followed_sources, @followed_countries, @saved_headlines) '
            'ON CONFLICT (id) DO NOTHING',
          ),
          parameters: () {
            final params = adminPreferences.toJson();
            params['user_id'] = adminUser.id;
            params['followed_topics'] = jsonEncode(params['followed_topics']);
            params['followed_sources'] = jsonEncode(params['followed_sources']);
            params['followed_countries'] = jsonEncode(
              params['followed_countries'],
            );
            params['saved_headlines'] = jsonEncode(params['saved_headlines']);
            return params;
          }(),
        );

        await _connection.execute('COMMIT');
        _log.info('Initial RemoteConfig and admin user seeding completed.');
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
