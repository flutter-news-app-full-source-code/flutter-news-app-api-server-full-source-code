 import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/config/environment_config.dart';
import 'package:ht_data_client/ht_data_client.dart';
import 'package:ht_data_postgres/ht_data_postgres.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

/// Global logger instance.
 final _log = Logger('ht_api');

/// Global PostgreSQL connection instance.
 late final Connection _connection;

/// Creates a data repository for a given type [T].
///
/// This helper function centralizes the creation of repositories,
/// ensuring they all use the same database connection and logger.
 HtDataRepository<T> _createRepository<T>({
  required String tableName,
  required FromJson<T> fromJson,
  required ToJson<T> toJson,
 }) {
  return HtDataRepository<T>(
    dataClient: HtDataPostgresClient<T>(
      connection: _connection,
      tableName: tableName,
      fromJson: fromJson,
      toJson: toJson,
      log: _log,
    ),
  );
 }

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

  _connection = await Connection.open(
    Endpoint(
      host: dbUri.host,
      port: dbUri.port,
      database: dbUri.path.substring(1), // Remove leading '/'
      username: username,
      password: password,
    ),
    // Using `require` is a more secure default. For local development against
    // a non-SSL database, this may need to be changed to `SslMode.disable`.
    settings: const ConnectionSettings(sslMode: SslMode.require),
  );
  _log.info('PostgreSQL database connection established.');

  // 3. Initialize Repositories
  final headlineRepository = _createRepository<Headline>(
    tableName: 'headlines',
    fromJson: Headline.fromJson,
    toJson: (h) => h.toJson(),
  );
  final categoryRepository = _createRepository<Category>(
    tableName: 'categories',
    fromJson: Category.fromJson,
    toJson: (c) => c.toJson(),
  );
  final sourceRepository = _createRepository<Source>(
    tableName: 'sources',
    fromJson: Source.fromJson,
    toJson: (s) => s.toJson(),
  );
  final countryRepository = _createRepository<Country>(
    tableName: 'countries',
    fromJson: Country.fromJson,
    toJson: (c) => c.toJson(),
  );
  final userRepository = _createRepository<User>(
    tableName: 'users',
    fromJson: User.fromJson,
    toJson: (u) => u.toJson(),
  );
  final userAppSettingsRepository = _createRepository<UserAppSettings>(
    tableName: 'user_app_settings',
    fromJson: UserAppSettings.fromJson,
    toJson: (s) => s.toJson(),
  );
  final userContentPreferencesRepository =
      _createRepository<UserContentPreferences>(
    tableName: 'user_content_preferences',
    fromJson: UserContentPreferences.fromJson,
    toJson: (p) => p.toJson(),
  );
  final appConfigRepository = _createRepository<AppConfig>(
    tableName: 'app_config',
    fromJson: AppConfig.fromJson,
    toJson: (c) => c.toJson(),
  );

  // 4. Create the main handler with all dependencies provided
  final finalHandler = handler
      .use(provider<Uuid>((_) => const Uuid()))
      .use(provider<HtDataRepository<Headline>>((_) => headlineRepository))
      .use(provider<HtDataRepository<Category>>((_) => categoryRepository))
      .use(provider<HtDataRepository<Source>>((_) => sourceRepository))
      .use(provider<HtDataRepository<Country>>((_) => countryRepository))
      .use(provider<HtDataRepository<User>>((_) => userRepository))
      .use(
        provider<HtDataRepository<UserAppSettings>>(
          (_) => userAppSettingsRepository,
        ),
      )
      .use(
        provider<HtDataRepository<UserContentPreferences>>(
          (_) => userContentPreferencesRepository,
        ),
      )
      .use(provider<HtDataRepository<AppConfig>>((_) => appConfigRepository));

  // 5. Start the server
  final server = await serve(
    finalHandler,
    ip,
    port,
  );
  _log.info('Server listening on port ${server.port}');

  // 6. Handle graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    _log.info('Received SIGINT. Shutting down...');
    await _connection.close();
    _log.info('Database connection closed.');
    await server.close(force: true);
    _log.info('Server shut down.');
    exit(0);
  });

  return server;
 }