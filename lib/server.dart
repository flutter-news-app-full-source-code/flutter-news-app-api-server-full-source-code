import 'dart:async';
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

/// The main entry point for the server, used by `dart_frog dev`.
///
/// This function is responsible for the entire server startup sequence:
/// 1.  **Gating Requests:** It immediately sets up a "gate" using a `Completer`
///     to hold all incoming requests until initialization is complete.
/// 2.  **Async Initialization:** It performs all necessary asynchronous setup,
///     including logging, database connection, and data seeding.
/// 3.  **Dependency Injection:** It initializes all repositories and services
///     and populates the `DependencyContainer`.
/// 4.  **Server Start:** It starts the HTTP server with the gated handler.
/// 5.  **Opening the Gate:** Once the server is listening, it completes the
///     `Completer`, allowing the gated requests to be processed.
/// 6.  **Graceful Shutdown:** It sets up a listener for `SIGINT` to close
///     resources gracefully.
Future<HttpServer> run(Handler handler, InternetAddress ip, int port) async {
  final initCompleter = Completer<void>();

  // This middleware wraps the main handler. It awaits the completer's future,
  // effectively pausing the request until `initCompleter.complete()` is called.
  final gatedHandler = handler.use((innerHandler) {
    return (context) async {
      await initCompleter.future;
      return innerHandler(context);
    };
  });

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
    settings: const ConnectionSettings(sslMode: SslMode.require),
  );
  _log.info('PostgreSQL database connection established.');

  // 3. Initialize and run database seeding
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
  final AuthTokenService authTokenService = JwtAuthTokenService(
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
  final dashboardSummaryService =
      DashboardSummaryService(
        headlineRepository: headlineRepository,
        categoryRepository: categoryRepository,
        sourceRepository: sourceRepository,
      );
  const permissionService = PermissionService();
  final UserPreferenceLimitService userPreferenceLimitService =
      DefaultUserPreferenceLimitService(
        appConfigRepository: appConfigRepository,
      );

  // 6. Populate the DependencyContainer
  DependencyContainer.instance.init(
    headlineRepository: headlineRepository,
    categoryRepository: categoryRepository,
    sourceRepository: sourceRepository,
    countryRepository: countryRepository,
    userRepository: userRepository,
    userAppSettingsRepository: userAppSettingsRepository,
    userContentPreferencesRepository: userContentPreferencesRepository,
    appConfigRepository: appConfigRepository,
    emailRepository: emailRepository,
    tokenBlacklistService: tokenBlacklistService,
    authTokenService: authTokenService,
    verificationCodeStorageService: verificationCodeStorageService,
    authService: authService,
    dashboardSummaryService: dashboardSummaryService,
    permissionService: permissionService,
    userPreferenceLimitService: userPreferenceLimitService,
  );

  // 7. Start the server with the gated handler
  final server = await serve(gatedHandler, ip, port);
  _log.info('Server listening on port ${server.port}');

  // 8. Open the gate now that the server is ready.
  initCompleter.complete();

  // 9. Handle graceful shutdown
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
