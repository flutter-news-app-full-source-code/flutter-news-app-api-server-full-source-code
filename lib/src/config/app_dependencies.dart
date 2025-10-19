// ignore_for_file: public_member_api_docs

import 'package:core/core.dart';
import 'package:data_mongodb/data_mongodb.dart';
import 'package:data_repository/data_repository.dart';
import 'package:email_repository/email_repository.dart';
import 'package:email_sendgrid/email_sendgrid.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/database/migrations/all_migrations.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/country_query_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/dashboard_summary_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/database_migration_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/database_seeding_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/default_user_preference_limit_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/jwt_auth_token_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/mongodb_rate_limit_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/mongodb_token_blacklist_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/mongodb_verification_code_storage_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/rate_limit_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/token_blacklist_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/user_preference_limit_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/verification_code_storage_service.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';

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

  final _log = Logger('AppDependencies');

  // A flag to track if initialization has started, for safe disposal.
  bool _initStarted = false;

  // --- Late-initialized fields for all dependencies ---

  // Database
  late final MongoDbConnectionManager _mongoDbConnectionManager;

  // Repositories
  late final DataRepository<Headline> headlineRepository;
  late final DataRepository<Topic> topicRepository;
  late final DataRepository<Source> sourceRepository;
  late final DataRepository<Country> countryRepository;
  late final DataRepository<Language> languageRepository;
  late final DataRepository<User> userRepository;
  late final DataRepository<UserAppSettings> userAppSettingsRepository;
  late final DataRepository<UserContentPreferences>
  userContentPreferencesRepository;
  late final DataRepository<RemoteConfig> remoteConfigRepository;
  late final DataRepository<LocalAd> localAdRepository;
  late final EmailRepository emailRepository;

  // Services
  late final DatabaseMigrationService databaseMigrationService;
  late final TokenBlacklistService tokenBlacklistService;
  late final AuthTokenService authTokenService;
  late final VerificationCodeStorageService verificationCodeStorageService;
  late final AuthService authService;
  late final DashboardSummaryService dashboardSummaryService;
  late final PermissionService permissionService;
  late final UserPreferenceLimitService userPreferenceLimitService;
  late final RateLimitService rateLimitService;
  late final CountryQueryService countryQueryService;

  /// Initializes all application dependencies.
  ///
  /// This method is now designed to be called once at application startup
  /// by the eager-loading entrypoint (`bin/main.dart`). It will throw an
  /// exception if any part of the initialization fails, which will be caught
  /// by the entrypoint to terminate the server process.
  Future<void> init() async {
    _initStarted = true;
    _log.info('Initializing application dependencies...');

    // 1. Initialize Database Connection
    _mongoDbConnectionManager = MongoDbConnectionManager();
    await _mongoDbConnectionManager.init(EnvironmentConfig.databaseUrl);
    _log.info('MongoDB connection established.');

    // 2. Initialize and Run Database Migrations
    databaseMigrationService = DatabaseMigrationService(
      db: _mongoDbConnectionManager.db,
      log: Logger('DatabaseMigrationService'),
      migrations:
          allMigrations, // From lib/src/database/migrations/all_migrations.dart
    );
    await databaseMigrationService.init();
    _log.info('Database migrations applied.');

    // 3. Seed Database
    // This runs AFTER migrations to ensure the schema is up-to-date.
    final seedingService = DatabaseSeedingService(
      db: _mongoDbConnectionManager.db,
      log: Logger('DatabaseSeedingService'),
    );
    await seedingService.seedInitialData();
    _log.info('Database seeding complete.');

    // 4. Initialize Data Clients (MongoDB implementation)
    final headlineClient = DataMongodb<Headline>(
      connectionManager: _mongoDbConnectionManager,
      modelName: 'headlines',
      fromJson: Headline.fromJson,
      toJson: (item) => item.toJson(),
      searchableFields: ['title'],
      logger: Logger('DataMongodb<Headline>'),
    );
    final topicClient = DataMongodb<Topic>(
      connectionManager: _mongoDbConnectionManager,
      modelName: 'topics',
      fromJson: Topic.fromJson,
      toJson: (item) => item.toJson(),
      searchableFields: ['name'],
      logger: Logger('DataMongodb<Topic>'),
    );
    final sourceClient = DataMongodb<Source>(
      connectionManager: _mongoDbConnectionManager,
      modelName: 'sources',
      fromJson: Source.fromJson,
      toJson: (item) => item.toJson(),
      searchableFields: ['name'],
      logger: Logger('DataMongodb<Source>'),
    );
    final countryClient = DataMongodb<Country>(
      connectionManager: _mongoDbConnectionManager,
      modelName: 'countries',
      fromJson: Country.fromJson,
      toJson: (item) => item.toJson(),
      searchableFields: ['name'],
      logger: Logger('DataMongodb<Country>'),
    );
    final languageClient = DataMongodb<Language>(
      connectionManager: _mongoDbConnectionManager,
      modelName: 'languages',
      fromJson: Language.fromJson,
      toJson: (item) => item.toJson(),
      logger: Logger('DataMongodb<Language>'),
    );
    final userClient = DataMongodb<User>(
      connectionManager: _mongoDbConnectionManager,
      modelName: 'users',
      fromJson: User.fromJson,
      toJson: (item) => item.toJson(),
      logger: Logger('DataMongodb<User>'),
    );
    final userAppSettingsClient = DataMongodb<UserAppSettings>(
      connectionManager: _mongoDbConnectionManager,
      modelName: 'user_app_settings',
      fromJson: UserAppSettings.fromJson,
      toJson: (item) => item.toJson(),
      logger: Logger('DataMongodb<UserAppSettings>'),
    );
    final userContentPreferencesClient = DataMongodb<UserContentPreferences>(
      connectionManager: _mongoDbConnectionManager,
      modelName: 'user_content_preferences',
      fromJson: UserContentPreferences.fromJson,
      toJson: (item) => item.toJson(),
      logger: Logger('DataMongodb<UserContentPreferences>'),
    );
    final remoteConfigClient = DataMongodb<RemoteConfig>(
      connectionManager: _mongoDbConnectionManager,
      modelName: 'remote_configs',
      fromJson: RemoteConfig.fromJson,
      toJson: (item) => item.toJson(),
      logger: Logger('DataMongodb<RemoteConfig>'),
    );

    // 4. Initialize Repositories
    headlineRepository = DataRepository(dataClient: headlineClient);
    topicRepository = DataRepository(dataClient: topicClient);
    sourceRepository = DataRepository(dataClient: sourceClient);
    countryRepository = DataRepository(dataClient: countryClient);
    languageRepository = DataRepository(dataClient: languageClient);
    userRepository = DataRepository(dataClient: userClient);
    userAppSettingsRepository = DataRepository(
      dataClient: userAppSettingsClient,
    );
    userContentPreferencesRepository = DataRepository(
      dataClient: userContentPreferencesClient,
    );
    remoteConfigRepository = DataRepository(dataClient: remoteConfigClient);
    // Configure the HTTP client for SendGrid.
    // The HttpClient's AuthInterceptor will use the tokenProvider to add
    // the 'Authorization: Bearer <SENDGRID_API_KEY>' header.
    final sendGridApiBase =
        EnvironmentConfig.sendGridApiUrl ?? 'https://api.sendgrid.com';
    final sendGridHttpClient = HttpClient(
      baseUrl: '$sendGridApiBase/v3',
      tokenProvider: () async => EnvironmentConfig.sendGridApiKey,
      logger: Logger('EmailSendgridClient'),
    );

    // Initialize the SendGrid email client with the dedicated HTTP client.
    final emailClient = EmailSendGrid(
      httpClient: sendGridHttpClient,
      log: Logger('EmailSendgrid'),
    );

    emailRepository = EmailRepository(emailClient: emailClient);

    final localAdClient = DataMongodb<LocalAd>(
      connectionManager: _mongoDbConnectionManager,
      modelName: 'local_ads',
      fromJson: LocalAd.fromJson,
      toJson: LocalAd.toJson,
      searchableFields: ['title'],
      logger: Logger('DataMongodb<LocalAd>'),
    );
    localAdRepository = DataRepository(dataClient: localAdClient);

    // 5. Initialize Services
    tokenBlacklistService = MongoDbTokenBlacklistService(
      connectionManager: _mongoDbConnectionManager,
      log: Logger('MongoDbTokenBlacklistService'),
    );
    authTokenService = JwtAuthTokenService(
      userRepository: userRepository,
      blacklistService: tokenBlacklistService,
      log: Logger('JwtAuthTokenService'),
    );
    verificationCodeStorageService = MongoDbVerificationCodeStorageService(
      connectionManager: _mongoDbConnectionManager,
      log: Logger('MongoDbVerificationCodeStorageService'),
    );
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
    rateLimitService = MongoDbRateLimitService(
      connectionManager: _mongoDbConnectionManager,
      log: Logger('MongoDbRateLimitService'),
    );
    countryQueryService = CountryQueryService(
      countryRepository: countryRepository,
      log: Logger('CountryQueryService'),
      cacheDuration: EnvironmentConfig.countryServiceCacheDuration,
    );

    _log.info('Application dependencies initialized successfully.');
  }

  /// Disposes of resources, such as closing the database connection.
  Future<void> dispose() async {
    if (_initStarted) {
      await _mongoDbConnectionManager.close();
    }
    tokenBlacklistService.dispose();
    rateLimitService.dispose();
    countryQueryService.dispose(); // Dispose the new service
    _log.info('Application dependencies disposed.');
  }
}
