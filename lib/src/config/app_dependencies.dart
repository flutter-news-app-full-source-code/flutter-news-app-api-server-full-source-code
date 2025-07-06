import 'dart:async';

import 'package:dotenv/dotenv.dart';
import 'package:ht_api/src/config/database_connection.dart';
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

/// A singleton class to manage all application dependencies.
///
/// This class follows a lazy initialization pattern. Dependencies are created
/// only when the `init()` method is first called, typically triggered by the
/// first incoming request. A `Completer` ensures that subsequent requests
/// await the completion of the initial setup.
class AppDependencies {
  AppDependencies._();

  /// The single, global instance of the [AppDependencies].
  static final instance = AppDependencies._();

  final _log = Logger('AppDependencies');
  final _completer = Completer<void>();

  // --- Repositories ---
  late final HtDataRepository<Headline> headlineRepository;
  late final HtDataRepository<Category> categoryRepository;
  late final HtDataRepository<Source> sourceRepository;
  late final HtDataRepository<Country> countryRepository;
  late final HtDataRepository<User> userRepository;
  late final HtDataRepository<UserAppSettings> userAppSettingsRepository;
  late final HtDataRepository<UserContentPreferences>
  userContentPreferencesRepository;
  late final HtDataRepository<AppConfig> appConfigRepository;

  // --- Services ---
  late final HtEmailRepository emailRepository;
  late final TokenBlacklistService tokenBlacklistService;
  late final AuthTokenService authTokenService;
  late final VerificationCodeStorageService verificationCodeStorageService;
  late final AuthService authService;
  late final DashboardSummaryService dashboardSummaryService;
  late final PermissionService permissionService;
  late final UserPreferenceLimitService userPreferenceLimitService;

  /// Initializes all application dependencies.
  ///
  /// This method is idempotent. It performs the full initialization only on
  /// the first call. Subsequent calls will await the result of the first one.
  Future<void> init() {
    if (_completer.isCompleted) {
      _log.fine('Dependencies already initializing/initialized.');
      return _completer.future;
    }

    _log.info('Initializing application dependencies...');
    _init()
        .then((_) {
          _log.info('Application dependencies initialized successfully.');
          _completer.complete();
        })
        .catchError((Object e, StackTrace s) {
          _log.severe('Failed to initialize application dependencies.', e, s);
          _completer.completeError(e, s);
        });

    return _completer.future;
  }

  Future<void> _init() async {
    // 0. Load environment variables from .env file.
    DotEnv(includePlatformEnvironment: true).load();
    _log.info('Environment variables loaded from .env file.');

    // 1. Establish Database Connection.
    await DatabaseConnectionManager.instance.init();
    final connection = await DatabaseConnectionManager.instance.connection;

    // 2. Run Database Seeding.
    final seedingService = DatabaseSeedingService(
      connection: connection,
      log: _log,
    );
    await seedingService.createTables();
    await seedingService.seedGlobalFixtureData();
    await seedingService.seedInitialAdminAndConfig();

    // 3. Initialize Repositories.
    headlineRepository = _createRepository(
      connection,
      'headlines',
      Headline.fromJson,
      (h) => h.toJson(),
    );
    categoryRepository = _createRepository(
      connection,
      'categories',
      Category.fromJson,
      (c) => c.toJson(),
    );
    sourceRepository = _createRepository(
      connection,
      'sources',
      Source.fromJson,
      (s) => s.toJson(),
    );
    countryRepository = _createRepository(
      connection,
      'countries',
      Country.fromJson,
      (c) => c.toJson(),
    );
    userRepository = _createRepository(
      connection,
      'users',
      User.fromJson,
      (u) => u.toJson(),
    );
    userAppSettingsRepository = _createRepository(
      connection,
      'user_app_settings',
      UserAppSettings.fromJson,
      (s) => s.toJson(),
    );
    userContentPreferencesRepository = _createRepository(
      connection,
      'user_content_preferences',
      UserContentPreferences.fromJson,
      (p) => p.toJson(),
    );
    appConfigRepository = _createRepository(
      connection,
      'app_config',
      AppConfig.fromJson,
      (c) => c.toJson(),
    );

    // 4. Initialize Services.
    emailRepository = const HtEmailRepository(
      emailClient: HtEmailInMemoryClient(),
    );
    tokenBlacklistService = InMemoryTokenBlacklistService();
    authTokenService = JwtAuthTokenService(
      userRepository: userRepository,
      blacklistService: tokenBlacklistService,
      uuidGenerator: const Uuid(),
    );
    verificationCodeStorageService = InMemoryVerificationCodeStorageService();
    authService = AuthService(
      userRepository: userRepository,
      authTokenService: authTokenService,
      verificationCodeStorageService: verificationCodeStorageService,
      emailRepository: emailRepository,
      userAppSettingsRepository: userAppSettingsRepository,
      userContentPreferencesRepository: userContentPreferencesRepository,
      uuidGenerator: const Uuid(),
    );
    dashboardSummaryService = DashboardSummaryService(
      headlineRepository: headlineRepository,
      categoryRepository: categoryRepository,
      sourceRepository: sourceRepository,
    );
    permissionService = const PermissionService();
    userPreferenceLimitService = DefaultUserPreferenceLimitService(
      appConfigRepository: appConfigRepository,
    );
  }

  HtDataRepository<T> _createRepository<T>(
    Connection connection,
    String tableName,
    FromJson<T> fromJson,
    ToJson<T> toJson,
  ) {
    return HtDataRepository<T>(
      dataClient: HtDataPostgresClient<T>(
        connection: connection,
        tableName: tableName,
        fromJson: fromJson,
        toJson: toJson,
        log: _log,
      ),
    );
  }
}
