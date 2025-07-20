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
import 'package:ht_data_mongodb/ht_data_mongodb.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_email_inmemory/ht_email_inmemory.dart';
import 'package:ht_email_repository/ht_email_repository.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

/// {@template app_dependencies}
/// A singleton class responsible for initializing and providing all application
/// dependencies, such as database connections, repositories, and services.
/// {@endtemplate}
class AppDependencies {
  /// Private constructor for the singleton pattern.
  AppDependencies._();

  /// The single, static instance of this class.
  static final AppDependencies _instance = AppDependencies._();

  /// Provides access to the singleton instance.
  static AppDependencies get instance => _instance;

  bool _isInitialized = false;
  Object? _initializationError;
  StackTrace? _initializationStackTrace;
  final _log = Logger('AppDependencies');

  // --- Late-initialized fields for all dependencies ---

  // Database
  late final MongoDbConnectionManager _mongoDbConnectionManager;

  // Repositories
  late final HtDataRepository<Headline> headlineRepository;
  late final HtDataRepository<Topic> topicRepository;
  late final HtDataRepository<Source> sourceRepository;
  late final HtDataRepository<Country> countryRepository;
  late final HtDataRepository<User> userRepository;
  late final HtDataRepository<UserAppSettings> userAppSettingsRepository;
  late final HtDataRepository<UserContentPreferences>
  userContentPreferencesRepository;
  late final HtDataRepository<RemoteConfig> remoteConfigRepository;
  late final HtEmailRepository emailRepository;

  // Services
  late final TokenBlacklistService tokenBlacklistService;
  late final AuthTokenService authTokenService;
  late final VerificationCodeStorageService verificationCodeStorageService;
  late final AuthService authService;
  late final DashboardSummaryService dashboardSummaryService;
  late final PermissionService permissionService;
  late final UserPreferenceLimitService userPreferenceLimitService;

  /// Initializes all application dependencies.
  ///
  /// This method is idempotent; it will only run the initialization logic once.
  Future<void> init() async {
    // If initialization previously failed, re-throw the original error.
    if (_initializationError != null) {
      return Future.error(_initializationError!, _initializationStackTrace);
    }

    if (_isInitialized) return;

    _log.info('Initializing application dependencies...');

    try {
      // 1. Initialize Database Connection
      _mongoDbConnectionManager = MongoDbConnectionManager();
      await _mongoDbConnectionManager.init(EnvironmentConfig.databaseUrl);
      _log.info('MongoDB connection established.');

      // 2. Seed Database
      final seedingService = DatabaseSeedingService(
        db: _mongoDbConnectionManager.db,
        log: Logger('DatabaseSeedingService'),
      );
      await seedingService.seedInitialData();
      _log.info('Database seeding complete.');

      // 3. Initialize Data Clients (MongoDB implementation)
      final headlineClient = HtDataMongodb<Headline>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'headlines',
        fromJson: Headline.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('HtDataMongodb<Headline>'),
      );
      final topicClient = HtDataMongodb<Topic>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'topics',
        fromJson: Topic.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('HtDataMongodb<Topic>'),
      );
      final sourceClient = HtDataMongodb<Source>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'sources',
        fromJson: Source.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('HtDataMongodb<Source>'),
      );
      final countryClient = HtDataMongodb<Country>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'countries',
        fromJson: Country.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('HtDataMongodb<Country>'),
      );
      final userClient = HtDataMongodb<User>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'users',
        fromJson: User.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('HtDataMongodb<User>'),
      );
      final userAppSettingsClient = HtDataMongodb<UserAppSettings>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'user_app_settings',
        fromJson: UserAppSettings.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('HtDataMongodb<UserAppSettings>'),
      );
      final userContentPreferencesClient =
          HtDataMongodb<UserContentPreferences>(
            connectionManager: _mongoDbConnectionManager,
            modelName: 'user_content_preferences',
            fromJson: UserContentPreferences.fromJson,
            toJson: (item) => item.toJson(),
            logger: Logger('HtDataMongodb<UserContentPreferences>'),
          );
      final remoteConfigClient = HtDataMongodb<RemoteConfig>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'remote_configs',
        fromJson: RemoteConfig.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('HtDataMongodb<RemoteConfig>'),
      );

      // 4. Initialize Repositories
      headlineRepository = HtDataRepository(dataClient: headlineClient);
      topicRepository = HtDataRepository(dataClient: topicClient);
      sourceRepository = HtDataRepository(dataClient: sourceClient);
      countryRepository = HtDataRepository(dataClient: countryClient);
      userRepository = HtDataRepository(dataClient: userClient);
      userAppSettingsRepository = HtDataRepository(
        dataClient: userAppSettingsClient,
      );
      userContentPreferencesRepository = HtDataRepository(
        dataClient: userContentPreferencesClient,
      );
      remoteConfigRepository = HtDataRepository(dataClient: remoteConfigClient);

      const emailClient =  HtEmailInMemoryClient();
      
      emailRepository = const HtEmailRepository(emailClient: emailClient);

      // 5. Initialize Services
      tokenBlacklistService = InMemoryTokenBlacklistService(
        log: Logger('InMemoryTokenBlacklistService'),
      );
      authTokenService = JwtAuthTokenService(
        userRepository: userRepository,
        blacklistService: tokenBlacklistService,
        uuidGenerator: const Uuid(),
        log: Logger('JwtAuthTokenService'),
      );
      verificationCodeStorageService = InMemoryVerificationCodeStorageService();
      permissionService = const PermissionService();
      authService = AuthService(
        userRepository: userRepository,
        authTokenService: authTokenService,
        verificationCodeStorageService: verificationCodeStorageService,
        permissionService: permissionService,
        emailRepository: emailRepository,
        userAppSettingsRepository: userAppSettingsRepository,
        userContentPreferencesRepository: userContentPreferencesRepository,
        log: Logger('AuthService'),
      );
      dashboardSummaryService = DashboardSummaryService(
        headlineRepository: headlineRepository,
        topicRepository: topicRepository,
        sourceRepository: sourceRepository,
      );
      userPreferenceLimitService = DefaultUserPreferenceLimitService(
        remoteConfigRepository: remoteConfigRepository,
        permissionService: permissionService,
        log: Logger('DefaultUserPreferenceLimitService'),
      );

      _isInitialized = true;
      _log.info('Application dependencies initialized successfully.');
    } catch (e, s) {
      _log.severe('Failed to initialize application dependencies', e, s);
      _initializationError = e;
      _initializationStackTrace = s;
      rethrow;
    }
  }

  /// Disposes of resources, such as closing the database connection.
  Future<void> dispose() async {
    if (!_isInitialized) return;
    await _mongoDbConnectionManager.close();
    tokenBlacklistService.dispose();
    _isInitialized = false;
    _log.info('Application dependencies disposed.');
  }
}
