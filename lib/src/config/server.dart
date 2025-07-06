import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/config/dependency_container.dart';
import 'package:ht_api/src/config/environment_config.dart';
import 'package:ht_api/src/rbac/permission_service.dart';
import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_api/src/services/auth_token_service.dart';
import 'package:ht_api/src/services/dashboard_summary_service.dart';
import 'package:ht_api/src/services/database_seeding_service.dart';
import 'package:ht_api/src/services/default_user_preference_limit_service.dart';
import 'package:ht_api/src/services/jwt_auth_token_service.dart';
import 'package:ht_api/src/services/token_blacklist_service.dart';
import 'package:ht_api/src/services/user_preference_limit_service.dart';
import 'package:ht_api/src/services/verification_code_storage_service.dart';
import 'package:ht_data_client/ht_data_client.dart';
import 'package:ht_data_postgres/ht_data_postgres.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_email_inmemory/ht_email_inmemory.dart';
import 'package:ht_email_repository/ht_email_repository.dart';
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

  // 3. Initialize and run database seeding
  // This runs on every startup. The operations are idempotent (`IF NOT EXISTS`,
  // `ON CONFLICT DO NOTHING`), so it's safe to run every time. This ensures
  // the database is always in a valid state, especially for first-time setup
  // in any environment.
  final seedingService = DatabaseSeedingService(
    connection: _connection,
    log: _log,
  );
  await seedingService.createTables();
  await seedingService.seedGlobalFixtureData();
  await seedingService.seedInitialAdminAndConfig();

  // 4. Initialize Repositories
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

  // 5. Initialize Services
  const emailRepository = HtEmailRepository(
    emailClient: HtEmailInMemoryClient(),
  );
  final tokenBlacklistService = InMemoryTokenBlacklistService();
  final authTokenService = JwtAuthTokenService(
    userRepository: userRepository,
    blacklistService: tokenBlacklistService,
    uuidGenerator: const Uuid(),
  );
  final verificationCodeStorageService =
      InMemoryVerificationCodeStorageService();
  final authService = AuthService(
    userRepository: userRepository,
    authTokenService: authTokenService,
    verificationCodeStorageService: verificationCodeStorageService,
    emailRepository: emailRepository,
    userAppSettingsRepository: userAppSettingsRepository,
    userContentPreferencesRepository: userContentPreferencesRepository,
    uuidGenerator: const Uuid(),
  );
  final dashboardSummaryService = DashboardSummaryService(
    headlineRepository: headlineRepository,
    categoryRepository: categoryRepository,
    sourceRepository: sourceRepository,
  );
  const permissionService = PermissionService();
  final userPreferenceLimitService = DefaultUserPreferenceLimitService(
    appConfigRepository: appConfigRepository,
  );

  // 6. Populate the DependencyContainer with all initialized instances.
  // This must be done before the server starts handling requests, as the
  // root middleware will read from this container to provide dependencies.
  DependencyContainer.instance.init(
    // Repositories
    headlineRepository: headlineRepository,
    categoryRepository: categoryRepository,
    sourceRepository: sourceRepository,
    countryRepository: countryRepository,
    userRepository: userRepository,
    userAppSettingsRepository: userAppSettingsRepository,
    userContentPreferencesRepository: userContentPreferencesRepository,
    appConfigRepository: appConfigRepository,
    emailRepository: emailRepository,
    // Services
    tokenBlacklistService: tokenBlacklistService,
    authTokenService: authTokenService,
    verificationCodeStorageService: verificationCodeStorageService,
    authService: authService,
    dashboardSummaryService: dashboardSummaryService,
    permissionService: permissionService,
    userPreferenceLimitService: userPreferenceLimitService,
  );

  // 7. Start the server.
  // The original `handler` from Dart Frog is used. The root middleware in
  // `routes/_middleware.dart` will now be responsible for injecting all the
  // dependencies from the `DependencyContainer` into the request context.
  final server = await serve(handler, ip, port);
  _log.info('Server listening on port ${server.port}');

  // 8. Handle graceful shutdown
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
