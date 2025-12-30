// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:core/core.dart';
import 'package:data_mongodb/data_mongodb.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/analytics/analytics.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/email/email_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/email/email_logging_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/email/email_onesignal_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/email/email_sendgrid_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/app_store_server_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/google_play_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/database/migrations/all_migrations.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/idempotency_record.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/analytics/analytics.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/country_query_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/database_migration_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/database_seeding_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/default_user_action_limit_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/email/email_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/firebase_push_notification_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/google_auth_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/jwt_auth_token_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/mongodb_rate_limit_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/mongodb_token_blacklist_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/mongodb_verification_code_storage_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/onesignal_push_notification_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/payment/payment.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/push_notification_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/push_notification_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/rate_limit_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/token_blacklist_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/user_action_limit_service.dart';
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

  // A Completer to manage the one-time asynchronous initialization.
  // This ensures the initialization logic runs only once.
  Completer<void>? _initCompleter;

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
  late final DataRepository<UserContext> userContextRepository;
  late final DataRepository<AppSettings> appSettingsRepository;
  late final DataRepository<UserContentPreferences>
  userContentPreferencesRepository;
  late final DataRepository<PushNotificationDevice>
  pushNotificationDeviceRepository;
  late final DataRepository<RemoteConfig> remoteConfigRepository;
  late final DataRepository<UserSubscription> userSubscriptionRepository;
  late final DataRepository<InAppNotification> inAppNotificationRepository;
  late final DataRepository<KpiCardData> kpiCardDataRepository;
  late final DataRepository<ChartCardData> chartCardDataRepository;
  late final DataRepository<RankedListCardData> rankedListCardDataRepository;
  late final DataRepository<IdempotencyRecord> idempotencyRepository;

  late final DataRepository<Engagement> engagementRepository;
  late final DataRepository<Report> reportRepository;
  late final DataRepository<AppReview> appReviewRepository;
  late final EmailService emailService;

  // Services
  late final AnalyticsSyncService analyticsSyncService;
  late final DatabaseMigrationService databaseMigrationService;
  late final TokenBlacklistService tokenBlacklistService;
  late final AuthTokenService authTokenService;
  late final VerificationCodeStorageService verificationCodeStorageService;
  late final AuthService authService;
  late final PermissionService permissionService;
  late final UserActionLimitService userActionLimitService;
  late final RateLimitService rateLimitService;
  late final CountryQueryService countryQueryService;
  late final IPushNotificationService pushNotificationService;
  late final IGoogleAuthService? googleAuthService;
  late final IPushNotificationClient? firebasePushNotificationClient;
  late final IPushNotificationClient? oneSignalPushNotificationClient;
  late final AppStoreServerClient? appStoreServerClient;
  late final GooglePlayClient? googlePlayClient;
  late final SubscriptionService subscriptionService;
  late final IdempotencyService idempotencyService;

  /// Initializes all application dependencies.
  ///
  /// This method is idempotent; it will only run the initialization logic once.
  Future<void> init() {
    // If _initCompleter is not null, it means initialization is either in
    // progress or has already completed. Return its future to allow callers
    // to await the single, shared initialization process.
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    // This is the first call to init(). Create the completer and start the
    // initialization process.
    _initCompleter = Completer<void>();
    _log.info('Starting application dependency initialization...');
    // We intentionally don't await this future here. The completer's future,
    // which is returned below, is what callers will await.
    unawaited(_initializeDependencies());

    // Return the future from the completer.
    return _initCompleter!.future;
  }

  /// The core logic for initializing all dependencies.
  /// This method is private and should only be called once by [init].
  Future<void> _initializeDependencies() async {
    _log.info('Initializing application dependencies...');
    try {
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
      final userContextClient = DataMongodb<UserContext>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'user_contexts',
        fromJson: UserContext.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('DataMongodb<UserContext>'),
      );
      final appSettingsClient = DataMongodb<AppSettings>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'app_settings',
        fromJson: AppSettings.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('DataMongodb<AppSettings>'),
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
      final userSubscriptionClient = DataMongodb<UserSubscription>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'user_subscriptions',
        fromJson: UserSubscription.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('DataMongodb<UserSubscription>'),
      );

      final idempotencyClient = DataMongodb<IdempotencyRecord>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'idempotency_records',
        fromJson: IdempotencyRecord.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('DataMongodb<IdempotencyRecord>'),
      );

      // Initialize Data Clients for Push Notifications
      final pushNotificationDeviceClient = DataMongodb<PushNotificationDevice>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'push_notification_devices',
        fromJson: PushNotificationDevice.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('DataMongodb<PushNotificationDevice>'),
      );

      final inAppNotificationClient = DataMongodb<InAppNotification>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'in_app_notifications',
        fromJson: InAppNotification.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('DataMongodb<InAppNotification>'),
      );

      final kpiCardDataClient = DataMongodb<KpiCardData>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'kpi_card_data',
        fromJson: KpiCardData.fromJson,
        toJson: (item) => item.toJson(),
      );
      final chartCardDataClient = DataMongodb<ChartCardData>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'chart_card_data',
        fromJson: ChartCardData.fromJson,
        toJson: (item) => item.toJson(),
      );
      final rankedListCardDataClient = DataMongodb<RankedListCardData>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'ranked_list_card_data',
        fromJson: RankedListCardData.fromJson,
        toJson: (item) => item.toJson(),
      );
      _log.info('Initialized data client for InAppNotification.');

      final engagementClient = DataMongodb<Engagement>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'engagements',
        fromJson: Engagement.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('DataMongodb<Engagement>'),
      );

      final reportClient = DataMongodb<Report>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'reports',
        fromJson: Report.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('DataMongodb<Report>'),
      );

      final appReviewClient = DataMongodb<AppReview>(
        connectionManager: _mongoDbConnectionManager,
        modelName: 'app_reviews',
        fromJson: AppReview.fromJson,
        toJson: (item) => item.toJson(),
        logger: Logger('DataMongodb<AppReview>'),
      );

      // --- Conditionally Initialize Push Notification Clients ---

      // Firebase
      final fcmProjectId = EnvironmentConfig.firebaseProjectId;
      final fcmClientEmail = EnvironmentConfig.firebaseClientEmail;
      final fcmPrivateKey = EnvironmentConfig.firebasePrivateKey;

      if (fcmProjectId != null &&
          fcmClientEmail != null &&
          fcmPrivateKey != null) {
        _log.info(
          'Firebase credentials found. Initializing Firebase client.',
        );
        googleAuthService = GoogleAuthService(
          log: Logger('GoogleAuthService'),
        );

        final firebaseHttpClient = HttpClient(
          baseUrl: 'https://fcm.googleapis.com/v1/projects/$fcmProjectId/',
          tokenProvider: () => googleAuthService!.getAccessToken(
            scope: 'https://www.googleapis.com/auth/cloud-platform',
          ),
          logger: Logger('FirebasePushNotificationClient'),
        );

        firebasePushNotificationClient = FirebasePushNotificationClient(
          httpClient: firebaseHttpClient,
          projectId: fcmProjectId,
          log: Logger('FirebasePushNotificationClient'),
        );
      } else {
        _log.warning(
          'One or more Firebase credentials not found. Firebase push notifications will be disabled.',
        );
        googleAuthService = null;
        firebasePushNotificationClient = null;
      }

      // OneSignal
      final osAppId = EnvironmentConfig.oneSignalAppId;
      final osApiKey = EnvironmentConfig.oneSignalRestApiKey;

      if (osAppId != null && osApiKey != null) {
        _log.info(
          'OneSignal credentials found. Initializing OneSignal client.',
        );
        final oneSignalHttpClient = HttpClient(
          baseUrl: 'https://onesignal.com/api/v1/',
          tokenProvider: () async => null,
          interceptors: [
            InterceptorsWrapper(
              onRequest: (options, handler) {
                options.headers['Authorization'] = 'Basic $osApiKey';
                return handler.next(options);
              },
            ),
          ],
          logger: Logger('OneSignalPushNotificationClient'),
        );

        oneSignalPushNotificationClient = OneSignalPushNotificationClient(
          httpClient: oneSignalHttpClient,
          appId: osAppId,
          log: Logger('OneSignalPushNotificationClient'),
        );
      } else {
        _log.warning(
          'One or more OneSignal credentials not found. OneSignal push notifications will be disabled.',
        );
        oneSignalPushNotificationClient = null;
      }

      // 4. Initialize Repositories
      headlineRepository = DataRepository(dataClient: headlineClient);
      topicRepository = DataRepository(dataClient: topicClient);
      sourceRepository = DataRepository(dataClient: sourceClient);
      countryRepository = DataRepository(dataClient: countryClient);
      languageRepository = DataRepository(dataClient: languageClient);
      userRepository = DataRepository(dataClient: userClient);
      userContextRepository = DataRepository(dataClient: userContextClient);
      appSettingsRepository = DataRepository(
        dataClient: appSettingsClient,
      );
      userContentPreferencesRepository = DataRepository(
        dataClient: userContentPreferencesClient,
      );
      remoteConfigRepository = DataRepository(dataClient: remoteConfigClient);
      pushNotificationDeviceRepository = DataRepository(
        dataClient: pushNotificationDeviceClient,
      );
      userSubscriptionRepository = DataRepository(
        dataClient: userSubscriptionClient,
      );
      inAppNotificationRepository = DataRepository(
        dataClient: inAppNotificationClient,
      );
      engagementRepository = DataRepository(dataClient: engagementClient);
      reportRepository = DataRepository(dataClient: reportClient);
      appReviewRepository = DataRepository(dataClient: appReviewClient);
      kpiCardDataRepository = DataRepository(dataClient: kpiCardDataClient);
      chartCardDataRepository = DataRepository(
        dataClient: chartCardDataClient,
      );
      rankedListCardDataRepository = DataRepository(
        dataClient: rankedListCardDataClient,
      );
      idempotencyRepository = DataRepository(dataClient: idempotencyClient);

      // --- Initialize Email Service ---
      EmailClient? emailClient;

      final emailProvider = EnvironmentConfig.emailProvider.toLowerCase();
      _log.info('Initializing Email Service with provider: $emailProvider');

      switch (emailProvider) {
        case 'logging':
          _log.warning(
            '=============================================================',
          );
          _log.warning(
            '⚠️  USING EMAIL LOGGING CLIENT - EMAILS WILL NOT BE SENT  ⚠️',
          );
          _log.warning('   This configuration is for LOCAL DEVELOPMENT ONLY.');
          _log.warning(
            '=============================================================',
          );
          emailClient = EmailLoggingClient(log: Logger('EmailLoggingClient'));
        case 'sendgrid':
          if (EnvironmentConfig.sendGridApiKey?.isEmpty ?? true) {
            throw StateError(
              'EMAIL_PROVIDER is set to "sendgrid" but SENDGRID_API_KEY is missing.',
            );
          }
          final sendGridApiBase =
              EnvironmentConfig.sendGridApiUrl ?? 'https://api.sendgrid.com';
          final sendGridHttpClient = HttpClient(
            baseUrl: '$sendGridApiBase/v3',
            tokenProvider: () async => EnvironmentConfig.sendGridApiKey,
            logger: Logger('EmailSendGridHttpClient'),
          );
          emailClient = EmailSendGridClient(
            httpClient: sendGridHttpClient,
            log: Logger('EmailSendGridClient'),
          );
        case 'onesignal':
          if ((EnvironmentConfig.oneSignalAppId?.isEmpty ?? true) ||
              (EnvironmentConfig.oneSignalRestApiKey?.isEmpty ?? true)) {
            throw StateError(
              'EMAIL_PROVIDER is set to "onesignal" but required OneSignal environment variables (ONESIGNAL_APP_ID, ONESIGNAL_REST_API_KEY) are missing or empty.',
            );
          }
          final oneSignalHttpClient = HttpClient(
            baseUrl: 'https://onesignal.com/api/v1/',
            tokenProvider: () async => null,
            interceptors: [
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  options.headers['Authorization'] =
                      'Basic ${EnvironmentConfig.oneSignalRestApiKey}';
                  return handler.next(options);
                },
              ),
            ],
            logger: Logger('EmailOneSignalHttpClient'),
          );
          emailClient = EmailOneSignalClient(
            appId: EnvironmentConfig.oneSignalAppId!,
            httpClient: oneSignalHttpClient,
            log: Logger('EmailOneSignalClient'),
          );
        default:
          throw StateError(
            'Invalid EMAIL_PROVIDER: "$emailProvider". Must be one of: ${_EmailProvider.values.map((e) => e.name).join(', ')}.',
          );
      }

      emailService = EmailService(
        emailClient: emailClient,
        log: Logger('EmailService'),
      );

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
        emailService: emailService,
        appSettingsRepository: appSettingsRepository,
        userContextRepository: userContextRepository,
        userContentPreferencesRepository: userContentPreferencesRepository,
        log: Logger('AuthService'),
      );
      userActionLimitService = DefaultUserActionLimitService(
        remoteConfigRepository: remoteConfigRepository,
        engagementRepository: engagementRepository,
        reportRepository: reportRepository,
        log: Logger('DefaultUserActionLimitService'),
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
      pushNotificationService = DefaultPushNotificationService(
        pushNotificationDeviceRepository: pushNotificationDeviceRepository,
        userContentPreferencesRepository: userContentPreferencesRepository,
        remoteConfigRepository: remoteConfigRepository,
        inAppNotificationRepository: inAppNotificationRepository,
        firebaseClient: firebasePushNotificationClient,
        oneSignalClient: oneSignalPushNotificationClient,
        log: Logger('DefaultPushNotificationService'),
      );

      idempotencyService = IdempotencyService(
        repository: idempotencyRepository,
        log: Logger('IdempotencyService'),
      );

      // --- Subscription Services ---
      if (EnvironmentConfig.appleAppStoreIssuerId != null &&
          EnvironmentConfig.appleAppStoreKeyId != null &&
          EnvironmentConfig.appleAppStorePrivateKey != null) {
        _log.info(
          'Apple App Store credentials found. Initializing App Store Server Client.',
        );
        appStoreServerClient = AppStoreServerClient(
          log: Logger('AppStoreServerClient'),
        );
      } else {
        _log.warning(
          'Apple App Store credentials not found. App Store Client disabled.',
        );
        appStoreServerClient = null;
      }

      // Google Play Client requires the GoogleAuthService which might be null
      // if credentials weren't provided. We handle this gracefully.
      if (googleAuthService != null) {
        _log.info(
          'Google Auth Service available. Initializing Google Play Client.',
        );
        googlePlayClient = GooglePlayClient(
          googleAuthService: googleAuthService!,
          log: Logger('GooglePlayClient'),
        );
      } else {
        _log.warning(
          'Google Auth Service not available. Google Play Client disabled.',
        );
        googlePlayClient = null;
      }

      subscriptionService = SubscriptionService(
        userSubscriptionRepository: userSubscriptionRepository,
        userRepository: userRepository,
        appStoreClient: appStoreServerClient,
        googlePlayClient: googlePlayClient,
        idempotencyService: idempotencyService,
        log: Logger('SubscriptionService'),
      );

      // --- Analytics Services ---
      final gaPropertyId = EnvironmentConfig.googleAnalyticsPropertyId;
      final mpProjectId = EnvironmentConfig.mixpanelProjectId;
      final mpUser = EnvironmentConfig.mixpanelServiceAccountUsername;
      final mpSecret = EnvironmentConfig.mixpanelServiceAccountSecret;

      GoogleAnalyticsDataClient? googleAnalyticsClient;
      if (gaPropertyId != null && googleAuthService != null) {
        _log.info(
          'Google Analytics credentials found. Initializing Google Analytics Client.',
        );
        final googleAnalyticsHttpClient = HttpClient(
          baseUrl: 'https://analyticsdata.googleapis.com/v1beta',
          tokenProvider: () => googleAuthService!.getAccessToken(
            scope: 'https://www.googleapis.com/auth/analytics.readonly',
          ),
          logger: Logger('GoogleAnalyticsHttpClient'),
        );

        googleAnalyticsClient = GoogleAnalyticsDataClient(
          headlineRepository: headlineRepository,
          firebaseAuthenticator: googleAuthService!,
          propertyId: gaPropertyId,
          log: Logger('GoogleAnalyticsDataClient'),
          httpClient: googleAnalyticsHttpClient,
        );
      } else {
        _log.warning(
          'Google Analytics client could not be initialized due to missing '
          'property ID or Firebase authenticator.',
        );
      }

      MixpanelDataClient? mixpanelClient;
      if (mpProjectId != null && mpUser != null && mpSecret != null) {
        _log.info(
          'Mixpanel credentials found. Initializing Mixpanel Client.',
        );
        mixpanelClient = MixpanelDataClient(
          headlineRepository: headlineRepository,
          projectId: mpProjectId,
          serviceAccountUsername: mpUser,
          serviceAccountSecret: mpSecret,
          log: Logger('MixpanelDataClient'),
        );
      } else {
        _log.warning(
          'Mixpanel client could not be initialized due to missing credentials.',
        );
      }

      final analyticsMetricMapper = AnalyticsMetricMapper();

      analyticsSyncService = AnalyticsSyncService(
        remoteConfigRepository: remoteConfigRepository,
        kpiCardRepository: kpiCardDataRepository,
        chartCardRepository: chartCardDataRepository,
        rankedListCardRepository: rankedListCardDataRepository,
        userRepository: userRepository,
        topicRepository: topicRepository,
        sourceRepository: sourceRepository,
        reportRepository: reportRepository,
        headlineRepository: headlineRepository,
        googleAnalyticsClient: googleAnalyticsClient,
        mixpanelClient: mixpanelClient,
        analyticsMetricMapper: analyticsMetricMapper,
        engagementRepository: engagementRepository,
        appReviewRepository: appReviewRepository,
        userSubscriptionRepository: userSubscriptionRepository,
        log: Logger('AnalyticsSyncService'),
      );

      _log.info('Application dependencies initialized successfully.');
      // Signal that initialization has completed successfully.
      _initCompleter!.complete();
    } catch (e, s) {
      _log.severe('Failed to initialize application dependencies', e, s);
      // Signal that initialization has failed.
      _initCompleter!.completeError(e, s);
      rethrow;
    }
  }

  /// Disposes of resources, such as closing the database connection.
  Future<void> dispose() async {
    // Only attempt to dispose if initialization has been started.
    if (_initCompleter == null) {
      _log.info('Dispose called, but dependencies were never initialized.');
      return;
    }

    // Wait for initialization to complete before disposing resources.
    // This prevents a race condition if dispose() is called during init().
    try {
      await _initCompleter!.future;
    } catch (_) {
      // Initialization may have failed, but we still proceed to dispose
      // any partially initialized resources.
      _log.warning(
        'Disposing dependencies after a failed initialization attempt.',
      );
    }

    _log.info('Disposing application dependencies...');
    await _mongoDbConnectionManager.close();
    tokenBlacklistService.dispose();
    rateLimitService.dispose();
    countryQueryService.dispose();

    // Reset the completer to allow for re-initialization (e.g., in tests).
    _initCompleter = null;
    _log.info('Application dependencies disposed and state reset.');
  }
}

enum _EmailProvider { sendgrid, onesignal, logging }
