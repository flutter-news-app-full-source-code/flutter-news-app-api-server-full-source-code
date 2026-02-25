import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/push_notification/push_notification_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/push_notification/push_notification_service.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';

class MockDataRepository<T> extends Mock implements DataRepository<T> {}

class MockIPushNotificationClient extends Mock
    implements IPushNotificationClient {}

class FakePushNotificationPayload extends Fake
    implements PushNotificationPayload {}

class FakeInAppNotification extends Fake implements InAppNotification {}

class MockHttpClient extends Mock implements HttpClient {}

class MockLogger extends Mock implements Logger {}

void main() {
  group('DefaultPushNotificationService', () {
    setUpAll(() {
      registerFallbackValue(StackTrace.empty);
      registerFallbackValue(FakePushNotificationPayload());
      registerFallbackValue(FakeInAppNotification());
      registerFallbackValue(const PaginationOptions());
    });

    late DataRepository<PushNotificationDevice>
    pushNotificationDeviceRepository;
    late DataRepository<UserContentPreferences>
    userContentPreferencesRepository;
    late DataRepository<RemoteConfig> remoteConfigRepository;
    late DataRepository<AppSettings> appSettingsRepository;
    late DataRepository<InAppNotification> inAppNotificationRepository;
    late IPushNotificationClient firebaseClient;
    late IPushNotificationClient oneSignalClient;
    late Logger logger;
    late DefaultPushNotificationService service;

    // Common test data
    final testUser = User(
      id: ObjectId().oid,
      email: 'test@example.com',
      role: UserRole.user,
      tier: AccessTier.standard,
      createdAt: DateTime.now(),
    );

    final testAppSettings = AppSettings(
      id: testUser.id,
      language: SupportedLanguage.en,
      displaySettings: const DisplaySettings(
        baseTheme: AppBaseTheme.system,
        accentTheme: AppAccentTheme.defaultBlue,
        fontFamily: 'SystemDefault',
        textScaleFactor: AppTextScaleFactor.medium,
        fontWeight: AppFontWeight.bold,
      ),
      feedSettings: const FeedSettings(
        feedItemDensity: FeedItemDensity.standard,
        feedItemImageStyle: FeedItemImageStyle.largeThumbnail,
        feedItemClickBehavior: FeedItemClickBehavior.defaultBehavior,
      ),
    );

    final testCountry = const Country(
      id: 'us',
      isoCode: 'US',
      name: {SupportedLanguage.en: 'United States'},
      flagUrl: 'https://flag.com/us.png',
    );

    final testHeadline = Headline(
      id: ObjectId().oid,
      title: const {SupportedLanguage.en: 'Test Headline'},
      url: 'http://example.com',
      imageUrl: 'http://example.com/image.png',
      source: Source(
        id: ObjectId().oid,
        name: const {SupportedLanguage.en: 'Test Source'},
        description: const {SupportedLanguage.en: 'Description'},
        url: '',
        sourceType: SourceType.aggregator,
        language: SupportedLanguage.en,
        headquarters: testCountry,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      ),
      eventCountry: testCountry,
      topic: Topic(
        id: ObjectId().oid,
        name: const {SupportedLanguage.en: 'Test Topic'},
        description: const {SupportedLanguage.en: 'Description'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
      isBreaking: true,
    );

    final matchingFilter = SavedHeadlineFilter(
      id: ObjectId().oid,
      userId: testUser.id,
      name: const {SupportedLanguage.en: 'Matching Filter'},
      isPinned: false,
      deliveryTypes: const {
        PushNotificationSubscriptionDeliveryType.breakingOnly,
      },
      criteria: HeadlineFilterCriteria(
        topics: [testHeadline.topic],
        sources: const [],
        countries: const [],
      ),
    );

    final nonMatchingFilter = SavedHeadlineFilter(
      id: ObjectId().oid,
      userId: testUser.id,
      name: const {SupportedLanguage.en: 'Non-Matching Filter'},
      isPinned: false,
      deliveryTypes: const {
        PushNotificationSubscriptionDeliveryType.breakingOnly,
      },
      criteria: HeadlineFilterCriteria(
        topics: [
          Topic(
            id: ObjectId().oid,
            name: const {SupportedLanguage.en: 'Different Topic'},
            description: const {SupportedLanguage.en: 'Description'},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
        ],
        sources: const [],
        countries: const [],
      ),
    );

    final testDevice = PushNotificationDevice(
      id: ObjectId().oid,
      userId: testUser.id,
      platform: DevicePlatform.android,
      providerTokens: const {PushNotificationProviders.firebase: 'test-token'},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final remoteConfig = RemoteConfig(
      id: 'remote_config_id',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      app: const AppConfig(
        maintenance: MaintenanceConfig(isUnderMaintenance: false),
        update: UpdateConfig(
          latestAppVersion: '1.0.0',
          isLatestVersionOnly: false,
          iosUpdateUrl: '',
          androidUpdateUrl: '',
        ),
        general: GeneralAppConfig(
          termsOfServiceUrl: '',
          privacyPolicyUrl: '',
        ),
        localization: LocalizationConfig(
          enabledLanguages: [SupportedLanguage.en],
          defaultLanguage: SupportedLanguage.en,
        ),
      ),
      features: const FeaturesConfig(
        onboarding: OnboardingConfig(
          isEnabled: true,
          appTour: AppTourConfig(isEnabled: true, isSkippable: true),
          initialPersonalization: InitialPersonalizationConfig(
            isEnabled: true,
            isSkippable: true,
            isCountrySelectionEnabled: true,
            isTopicSelectionEnabled: true,
            isSourceSelectionEnabled: true,
          ),
        ),
        analytics: AnalyticsConfig(
          enabled: true,
          activeProvider: AnalyticsProviders.firebase,
          disabledEvents: {},
          eventSamplingRates: {},
        ),
        ads: AdConfig(
          enabled: true,
          primaryAdPlatform: AdPlatformType.admob,
          platformAdIdentifiers: {},
          feedAdConfiguration: FeedAdConfiguration(
            enabled: true,
            adType: AdType.native,
            visibleTo: {},
          ),
          navigationAdConfiguration: NavigationAdConfiguration(
            enabled: true,
            visibleTo: {},
          ),
        ),
        pushNotifications: PushNotificationConfig(
          enabled: true,
          primaryProvider: PushNotificationProviders.firebase,
          deliveryConfigs: {
            PushNotificationSubscriptionDeliveryType.breakingOnly: true,
          },
        ),
        feed: FeedConfig(
          itemClickBehavior: FeedItemClickBehavior.defaultBehavior,
          decorators: {},
        ),
        community: CommunityConfig(
          enabled: true,
          engagement: EngagementConfig(
            enabled: true,
            engagementMode: EngagementMode.reactionsAndComments,
          ),
          reporting: ReportingConfig(
            enabled: true,
            headlineReportingEnabled: true,
            sourceReportingEnabled: true,
            commentReportingEnabled: true,
          ),
          appReview: AppReviewConfig(
            enabled: true,
            interactionCycleThreshold: 5,
            initialPromptCooldownDays: 7,
            eligiblePositiveInteractions: [],
            isNegativeFeedbackFollowUpEnabled: true,
            isPositiveFeedbackFollowUpEnabled: true,
          ),
        ),
        rewards: RewardsConfig(enabled: true, rewards: {}),
      ),
      user: const UserConfig(
        limits: UserLimitsConfig(
          followedItems: {},
          savedHeadlines: {},
          savedHeadlineFilters: {},
          reactionsPerDay: {},
          commentsPerDay: {},
          reportsPerDay: {},
        ),
      ),
    );

    setUp(() {
      pushNotificationDeviceRepository = MockDataRepository();
      userContentPreferencesRepository = MockDataRepository();
      remoteConfigRepository = MockDataRepository();
      appSettingsRepository = MockDataRepository();
      inAppNotificationRepository = MockDataRepository();
      firebaseClient = MockIPushNotificationClient();
      oneSignalClient = MockIPushNotificationClient();
      logger = MockLogger();

      service = DefaultPushNotificationService(
        pushNotificationDeviceRepository: pushNotificationDeviceRepository,
        userContentPreferencesRepository: userContentPreferencesRepository,
        remoteConfigRepository: remoteConfigRepository,
        appSettingsRepository: appSettingsRepository,
        inAppNotificationRepository: inAppNotificationRepository,
        firebaseClient: firebaseClient,
        oneSignalClient: oneSignalClient,
        log: logger,
      );

      // Mute logger
      when(() => logger.info(any(), any(), any())).thenReturn(null);
      when(() => logger.finer(any(), any(), any())).thenReturn(null);
      when(() => logger.severe(any(), any(), any())).thenReturn(null);
      when(() => logger.warning(any(), any(), any())).thenReturn(null);

      // Default successful stubs
      when(
        () => remoteConfigRepository.read(id: any(named: 'id')),
      ).thenAnswer((_) async => remoteConfig);
      when(
        () => inAppNotificationRepository.create(item: any(named: 'item')),
      ).thenAnswer(
        (invocation) async => InAppNotification.fromJson(
          (invocation.namedArguments[#item] as InAppNotification).toJson(),
        ),
      );
      when(
        () => firebaseClient.sendBulkNotifications(
          deviceTokens: any(named: 'deviceTokens'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => const PushNotificationResult());
      when(
        () => pushNotificationDeviceRepository.delete(id: any(named: 'id')),
      ).thenAnswer((_) async {});
      when(
        () => appSettingsRepository.readAll(
          filter: any(named: 'filter'),
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer(
        (_) async => PaginatedResponse(
          items: [testAppSettings],
          cursor: null,
          hasMore: false,
        ),
      );
    });

    group('sendBreakingNewsNotification', () {
      test('sends notification when user has a matching filter', () async {
        when(
          () => userContentPreferencesRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [
              UserContentPreferences(
                id: testUser.id,
                followedCountries: const [],
                followedSources: const [],
                followedTopics: const [],
                savedHeadlines: const [],
                savedHeadlineFilters: [matchingFilter],
              ),
            ],
            cursor: null,
            hasMore: false,
          ),
        );
        when(
          () => pushNotificationDeviceRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [testDevice],
            cursor: null,
            hasMore: false,
          ),
        );

        await service.sendBreakingNewsNotification(headline: testHeadline);

        verify(
          () => firebaseClient.sendBulkNotifications(
            deviceTokens: [testDevice.providerTokens.values.first],
            payload: any(named: 'payload'),
          ),
        ).called(1);
        verify(
          () => inAppNotificationRepository.create(item: any(named: 'item')),
        ).called(1);
      });

      test(
        'does NOT send notification when user filter does not match',
        () async {
          when(
            () => userContentPreferencesRepository.readAll(
              filter: any(named: 'filter'),
              pagination: any(named: 'pagination'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [
                UserContentPreferences(
                  id: testUser.id,
                  followedCountries: const [],
                  followedSources: const [],
                  followedTopics: const [],
                  savedHeadlines: const [],
                  savedHeadlineFilters: [nonMatchingFilter],
                ),
              ],
              cursor: null,
              hasMore: false,
            ),
          );

          await service.sendBreakingNewsNotification(headline: testHeadline);

          verifyNever(
            () => firebaseClient.sendBulkNotifications(
              deviceTokens: any(named: 'deviceTokens'),
              payload: any(named: 'payload'),
            ),
          );
        },
      );

      test('aborts when push notifications are globally disabled', () async {
        when(
          () => remoteConfigRepository.read(id: any(named: 'id')),
        ).thenAnswer(
          (_) async => remoteConfig.copyWith(
            features: remoteConfig.features.copyWith(
              pushNotifications: remoteConfig.features.pushNotifications
                  .copyWith(enabled: false),
            ),
          ),
        );

        await service.sendBreakingNewsNotification(headline: testHeadline);

        verify(
          () => logger.info(any(that: contains('disabled')), any(), any()),
        ).called(1);
        verifyNever(
          () => userContentPreferencesRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        );
      });

      test('aborts when no users are subscribed', () async {
        when(
          () => userContentPreferencesRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedResponse(
            items: [],
            cursor: null,
            hasMore: false,
          ),
        );

        await service.sendBreakingNewsNotification(headline: testHeadline);

        verify(
          () => logger.info(
            any(that: contains('No users subscribed')),
          ),
        ).called(1);
        verifyNever(
          () => pushNotificationDeviceRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        );
      });

      test('cleans up invalid tokens on failure', () async {
        const invalidToken = 'invalid-token';
        when(
          () => userContentPreferencesRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [
              UserContentPreferences(
                id: testUser.id,
                followedCountries: const [],
                followedSources: const [],
                followedTopics: const [],
                savedHeadlines: const [],
                savedHeadlineFilters: [matchingFilter],
              ),
            ],
            cursor: null,
            hasMore: false,
          ),
        );
        when(
          () => pushNotificationDeviceRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [testDevice],
            cursor: null,
            hasMore: false,
          ),
        );
        when(
          () => firebaseClient.sendBulkNotifications(
            deviceTokens: any(named: 'deviceTokens'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer(
          (_) async => const PushNotificationResult(
            failedTokens: [invalidToken],
          ),
        );
        // Mock the readAll for cleanup
        when(
          () => pushNotificationDeviceRepository.readAll(
            filter: any(
              named: 'filter',
              that: predicate<Map<String, dynamic>>((filter) {
                if (!filter.containsKey('providerTokens.firebase')) {
                  return false;
                }
                final providerTokensFilter = filter['providerTokens.firebase'];
                if (providerTokensFilter is! Map ||
                    !providerTokensFilter.containsKey(r'$in')) {
                  return false;
                }
                final inValues = providerTokensFilter[r'$in'];
                return inValues is List && inValues.contains(invalidToken);
              }),
            ),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [
              testDevice.copyWith(
                providerTokens: {
                  PushNotificationProviders.firebase: invalidToken,
                },
              ),
            ],
            cursor: null,
            hasMore: false,
          ),
        );

        await service.sendBreakingNewsNotification(headline: testHeadline);

        // Wait for the unawaited cleanup future to complete in the test environment.
        await Future<void>.delayed(Duration.zero);

        verify(
          () => pushNotificationDeviceRepository.delete(id: testDevice.id),
        ).called(1);
      });

      test('omits Base64 image from payload', () async {
        final headlineWithBase64 = testHeadline.copyWith(
          imageUrl: const ValueWrapper(
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA',
          ),
        );
        when(
          () => userContentPreferencesRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [
              UserContentPreferences(
                id: testUser.id,
                followedCountries: const [],
                followedSources: const [],
                followedTopics: const [],
                savedHeadlines: const [],
                savedHeadlineFilters: [matchingFilter],
              ),
            ],
            cursor: null,
            hasMore: false,
          ),
        );
        when(
          () => pushNotificationDeviceRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [testDevice],
            cursor: null,
            hasMore: false,
          ),
        );

        await service.sendBreakingNewsNotification(
          headline: headlineWithBase64,
        );

        final captured =
            verify(
                  () => firebaseClient.sendBulkNotifications(
                    deviceTokens: any(named: 'deviceTokens'),
                    payload: captureAny(named: 'payload'),
                  ),
                ).captured.first
                as PushNotificationPayload;

        expect(captured.imageUrl, isNull);
      });

      test('aborts when breaking news delivery type is disabled', () async {
        when(
          () => remoteConfigRepository.read(id: any(named: 'id')),
        ).thenAnswer(
          (_) async => remoteConfig.copyWith(
            features: remoteConfig.features.copyWith(
              pushNotifications: remoteConfig.features.pushNotifications
                  .copyWith(
                    deliveryConfigs: {
                      PushNotificationSubscriptionDeliveryType.breakingOnly:
                          false,
                    },
                  ),
            ),
          ),
        );

        await service.sendBreakingNewsNotification(headline: testHeadline);

        verify(
          () => logger.info(
            any(that: contains('Breaking news notifications are disabled')),
            any(),
            any(),
          ),
        ).called(1);
        verifyNever(
          () => userContentPreferencesRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        );
      });

      test('aborts when eligible users have no registered devices', () async {
        when(
          () => userContentPreferencesRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [
              UserContentPreferences(
                id: testUser.id,
                followedCountries: const [],
                followedSources: const [],
                followedTopics: const [],
                savedHeadlines: const [],
                savedHeadlineFilters: [matchingFilter],
              ),
            ],
            cursor: null,
            hasMore: false,
          ),
        );
        // Return no devices
        when(
          () => pushNotificationDeviceRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedResponse(
            items: [],
            cursor: null,
            hasMore: false,
          ),
        );

        await service.sendBreakingNewsNotification(headline: testHeadline);

        verify(
          () => logger.info(
            any(that: contains('No registered devices found')),
            any(),
            any(),
          ),
        ).called(1);
        verifyNever(
          () => firebaseClient.sendBulkNotifications(
            deviceTokens: any(named: 'deviceTokens'),
            payload: any(named: 'payload'),
          ),
        );
      });

      test(
        'aborts when devices do not have a token for the primary provider',
        () async {
          final deviceWithOtherProvider = testDevice.copyWith(
            providerTokens: {
              PushNotificationProviders.oneSignal: 'onesignal-token',
            },
          );
          when(
            () => userContentPreferencesRepository.readAll(
              filter: any(named: 'filter'),
              pagination: any(named: 'pagination'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [
                UserContentPreferences(
                  id: testUser.id,
                  followedCountries: const [],
                  followedSources: const [],
                  followedTopics: const [],
                  savedHeadlines: const [],
                  savedHeadlineFilters: [matchingFilter],
                ),
              ],
              cursor: null,
              hasMore: false,
            ),
          );
          when(
            () => pushNotificationDeviceRepository.readAll(
              filter: any(named: 'filter'),
              pagination: any(named: 'pagination'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [deviceWithOtherProvider],
              cursor: null,
              hasMore: false,
            ),
          );

          await service.sendBreakingNewsNotification(headline: testHeadline);

          verify(
            () => logger.info(
              any(
                that: contains(
                  'No devices found with a token for the primary provider',
                ),
              ),
              any(),
              any(),
            ),
          ).called(1);
          verifyNever(
            () => firebaseClient.sendBulkNotifications(
              deviceTokens: any(named: 'deviceTokens'),
              payload: any(named: 'payload'),
            ),
          );
        },
      );

      group('criteria matching', () {
        test(
          'sends notification when filter has empty criteria lists (wildcard)',
          () async {
            final wildcardFilter = matchingFilter.copyWith(
              criteria: const HeadlineFilterCriteria(
                topics: [],
                sources: [],
                countries: [],
              ),
            );

            when(
              () => userContentPreferencesRepository.readAll(
                filter: any(named: 'filter'),
                pagination: any(named: 'pagination'),
              ),
            ).thenAnswer(
              (_) async => PaginatedResponse(
                items: [
                  UserContentPreferences(
                    id: testUser.id,
                    followedCountries: const [],
                    followedSources: const [],
                    followedTopics: const [],
                    savedHeadlines: const [],
                    savedHeadlineFilters: [wildcardFilter],
                  ),
                ],
                cursor: null,
                hasMore: false,
              ),
            );
            when(
              () => pushNotificationDeviceRepository.readAll(
                filter: any(named: 'filter'),
                pagination: any(named: 'pagination'),
              ),
            ).thenAnswer(
              (_) async => PaginatedResponse(
                items: [testDevice],
                cursor: null,
                hasMore: false,
              ),
            );

            await service.sendBreakingNewsNotification(headline: testHeadline);

            verify(
              () => firebaseClient.sendBulkNotifications(
                deviceTokens: any(named: 'deviceTokens'),
                payload: any(named: 'payload'),
              ),
            ).called(1);
          },
        );

        test('does NOT send when topic mismatches', () async {
          final wrongTopicFilter = matchingFilter.copyWith(
            criteria: matchingFilter.criteria.copyWith(
              topics: [
                Topic(
                  id: ObjectId().oid,
                  name: const {SupportedLanguage.en: 'Wrong Topic'},
                  description: const {SupportedLanguage.en: 'Description'},
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  status: ContentStatus.active,
                ),
              ],
            ),
          );

          when(
            () => userContentPreferencesRepository.readAll(
              filter: any(named: 'filter'),
              pagination: any(named: 'pagination'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [
                UserContentPreferences(
                  id: testUser.id,
                  followedCountries: const [],
                  followedSources: const [],
                  followedTopics: const [],
                  savedHeadlines: const [],
                  savedHeadlineFilters: [wrongTopicFilter],
                ),
              ],
              cursor: null,
              hasMore: false,
            ),
          );

          await service.sendBreakingNewsNotification(headline: testHeadline);

          verifyNever(
            () => firebaseClient.sendBulkNotifications(
              deviceTokens: any(named: 'deviceTokens'),
              payload: any(named: 'payload'),
            ),
          );
        });

        test(
          'sends notification when filter matches on source only',
          () async {
            final sourceOnlyFilter = matchingFilter.copyWith(
              criteria: HeadlineFilterCriteria(
                topics: const [],
                sources: [testHeadline.source],
                countries: const [],
              ),
            );

            when(
              () => userContentPreferencesRepository.readAll(
                filter: any(named: 'filter'),
                pagination: any(named: 'pagination'),
              ),
            ).thenAnswer(
              (_) async => PaginatedResponse(
                items: [
                  UserContentPreferences(
                    id: testUser.id,
                    followedCountries: const [],
                    followedSources: const [],
                    followedTopics: const [],
                    savedHeadlines: const [],
                    savedHeadlineFilters: [sourceOnlyFilter],
                  ),
                ],
                cursor: null,
                hasMore: false,
              ),
            );
            when(
              () => pushNotificationDeviceRepository.readAll(
                filter: any(named: 'filter'),
                pagination: any(named: 'pagination'),
              ),
            ).thenAnswer(
              (_) async => PaginatedResponse(
                items: [testDevice],
                cursor: null,
                hasMore: false,
              ),
            );

            await service.sendBreakingNewsNotification(headline: testHeadline);

            verify(
              () => firebaseClient.sendBulkNotifications(
                deviceTokens: any(
                  named: 'deviceTokens',
                  that: isNotEmpty,
                ),
                payload: any(named: 'payload'),
              ),
            ).called(1);
          },
        );
      });

      test('sends to multiple devices for a single user', () async {
        final device2 = testDevice.copyWith(
          id: ObjectId().oid,
          providerTokens: {
            PushNotificationProviders.firebase: 'test-token-2',
          },
        );

        when(
          () => userContentPreferencesRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [
              UserContentPreferences(
                id: testUser.id,
                followedCountries: const [],
                followedSources: const [],
                followedTopics: const [],
                savedHeadlines: const [],
                savedHeadlineFilters: [matchingFilter],
              ),
            ],
            cursor: null,
            hasMore: false,
          ),
        );
        when(
          () => pushNotificationDeviceRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [testDevice, device2],
            cursor: null,
            hasMore: false,
          ),
        );

        await service.sendBreakingNewsNotification(headline: testHeadline);

        final captured =
            verify(
                  () => firebaseClient.sendBulkNotifications(
                    deviceTokens: captureAny(named: 'deviceTokens'),
                    payload: any(named: 'payload'),
                  ),
                ).captured.first
                as List<String>;

        expect(captured, contains('test-token'));
        expect(captured, contains('test-token-2'));
        expect(captured.length, 2);
      });

      test('aborts if primary provider client is not initialized', () async {
        // Create a service instance where the firebase client is null
        final serviceWithNullClient = DefaultPushNotificationService(
          pushNotificationDeviceRepository: pushNotificationDeviceRepository,
          userContentPreferencesRepository: userContentPreferencesRepository,
          remoteConfigRepository: remoteConfigRepository,
          appSettingsRepository: appSettingsRepository,
          inAppNotificationRepository: inAppNotificationRepository,
          firebaseClient: null, // Explicitly null
          oneSignalClient: oneSignalClient,
          log: logger,
        );

        await serviceWithNullClient.sendBreakingNewsNotification(
          headline: testHeadline,
        );

        verify(
          () => logger.severe(
            any(that: contains('client could not be')),
            any(),
            any(),
          ),
        ).called(1);
        verifyNever(
          () => userContentPreferencesRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        );
      });

      test('resolves notification title to user preferred language', () async {
        final spanishUser = testUser.copyWith(id: ObjectId().oid);
        final spanishDevice = testDevice.copyWith(
          id: ObjectId().oid,
          userId: spanishUser.id,
        );

        final multilingualHeadline = testHeadline.copyWith(
          title: {
            SupportedLanguage.en: 'English Title',
            SupportedLanguage.es: 'Título en Español',
          },
        );

        final spanishFilter = matchingFilter.copyWith(
          id: ObjectId().oid,
          userId: spanishUser.id,
        );

        // Mock User Preferences
        when(
          () => userContentPreferencesRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [
              UserContentPreferences(
                id: spanishUser.id,
                followedCountries: const [],
                followedSources: const [],
                followedTopics: const [],
                savedHeadlines: const [],
                savedHeadlineFilters: [spanishFilter],
              ),
            ],
            cursor: null,
            hasMore: false,
          ),
        );

        // Mock App Settings (Spanish)
        when(
          () => appSettingsRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [
              testAppSettings.copyWith(
                id: spanishUser.id,
                language: SupportedLanguage.es,
              ),
            ],
            cursor: null,
            hasMore: false,
          ),
        );

        // Mock Devices
        when(
          () => pushNotificationDeviceRepository.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [spanishDevice],
            cursor: null,
            hasMore: false,
          ),
        );

        await service.sendBreakingNewsNotification(
          headline: multilingualHeadline,
        );

        // Verify the payload sent to the client has the Spanish title
        final capturedPayload =
            verify(
                  () => firebaseClient.sendBulkNotifications(
                    deviceTokens: any(named: 'deviceTokens'),
                    payload: captureAny(named: 'payload'),
                  ),
                ).captured.first
                as PushNotificationPayload;

        expect(capturedPayload.title, equals('Título en Español'));
      });
    });
  });
}
