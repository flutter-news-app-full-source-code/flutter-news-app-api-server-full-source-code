// ignore_for_file: inference_failure_on_function_invocation, unnecessary_lambdas, inference_failure_on_collection_literal
import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:verity_api/src/clients/intelligence/intelligence_client.dart';
import 'package:verity_api/src/config/environment_config.dart';
import 'package:verity_api/src/models/intelligence/ai_usage.dart';
import 'package:verity_api/src/services/intelligence/identity_resolution_service.dart';
import 'package:verity_api/src/services/intelligence/intelligence_service.dart';
import 'package:verity_api/src/services/intelligence/strategies/ai_strategy.dart';
import 'package:verity_api/src/services/push_notification/push_notification_service.dart';

class MockIntelligenceClient extends Mock implements IntelligenceClient {}

class MockUsageRepository extends Mock implements DataRepository<AiUsage> {}

class MockTopicRepository extends Mock implements DataRepository<Topic> {}

class MockRemoteConfigRepository extends Mock
    implements DataRepository<RemoteConfig> {}

class MockHeadlineRepository extends Mock implements DataRepository<Headline> {}

class MockCountryRepository extends Mock implements DataRepository<Country> {}

class MockIdentityResolutionService extends Mock
    implements IdentityResolutionService {}

class MockPushNotificationService extends Mock
    implements IPushNotificationService {}

class MockLogger extends Mock implements Logger {}

class FakeAiStrategy extends Fake implements AiStrategy<String, String> {
  @override
  String get identifier => 'fake_strategy';

  @override
  List<Map<String, String>> buildPrompt(
    String input, {
    required List<SupportedLanguage> enabledLanguages,
    List<String> predefinedChoices = const [],
  }) {
    return [
      {'role': 'user', 'content': input},
    ];
  }

  @override
  String mapResponse(
    Map<String, dynamic> data,
    String input,
    List<SupportedLanguage> enabledLanguages,
  ) {
    return data['result'] as String;
  }
}

class FakeHeadline extends Fake implements Headline {}

class FakeAiUsage extends Fake implements AiUsage {}

class FakePerson extends Fake implements Person {}

void main() {
  late IntelligenceService service;
  late MockIntelligenceClient mockClient;
  late MockUsageRepository mockUsageRepo;
  late MockTopicRepository mockTopicRepo;
  late MockRemoteConfigRepository mockRemoteConfigRepo;
  late MockLogger mockLogger;
  late MockHeadlineRepository mockHeadlineRepo;
  late MockCountryRepository mockCountryRepo;
  late MockIdentityResolutionService mockIdentityService;
  late MockPushNotificationService mockPushService;

  late Headline draftHeadline;

  setUp(() {
    mockClient = MockIntelligenceClient();
    mockUsageRepo = MockUsageRepository();
    mockTopicRepo = MockTopicRepository();
    mockRemoteConfigRepo = MockRemoteConfigRepository();
    mockHeadlineRepo = MockHeadlineRepository();
    mockCountryRepo = MockCountryRepository();
    mockIdentityService = MockIdentityResolutionService();
    mockPushService = MockPushNotificationService();
    mockLogger = MockLogger();

    registerFallbackValue(FakeAiUsage());
    registerFallbackValue(FakeHeadline());
    registerFallbackValue(const PaginationOptions());

    service = IntelligenceService(
      client: mockClient,
      usageRepository: mockUsageRepo,
      topicRepository: mockTopicRepo,
      remoteConfigRepository: mockRemoteConfigRepo,
      headlineRepository: mockHeadlineRepo,
      countryRepository: mockCountryRepo,
      identityResolutionService: mockIdentityService,
      pushNotificationService: mockPushService,
      log: mockLogger,
    );

    // Default Config Overrides
    EnvironmentConfig.setOverride('AI_INGESTION_ENABLED', 'true');
    EnvironmentConfig.setOverride('AI_DAILY_TOKEN_QUOTA', '1000');

    // Default RemoteConfig Mock
    when(
      () => mockRemoteConfigRepo.readAll(
        pagination: any(named: 'pagination'),
      ),
    ).thenAnswer(
      (_) async => PaginatedResponse(
        items: [
          RemoteConfig(
            id: 'config',
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
                deliveryConfigs: {},
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
                  initialPromptCooldownDays: 30,
                  eligiblePositiveInteractions: [],
                  isNegativeFeedbackFollowUpEnabled: true,
                  isPositiveFeedbackFollowUpEnabled: false,
                ),
              ),
              rewards: RewardsConfig(enabled: true, rewards: {}),
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
          ),
        ],
        cursor: null,
        hasMore: false,
      ),
    );

    draftHeadline = Headline(
      id: 'h1',
      title: const {SupportedLanguage.en: 'Draft Title'},
      url: '',
      source: Source(
        id: 's1',
        name: const {SupportedLanguage.en: 'Source'},
        description: const {},
        url: '',
        sourceType: SourceType.blog,
        language: SupportedLanguage.en,
        headquarters: const Country(
          id: 'c1',
          isoCode: 'US',
          name: {},
          flagUrl: '',
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        status: ContentStatus.active,
      ),
      topic: Topic(
        id: 't1',
        name: const {SupportedLanguage.en: 'Tech'},
        description: const {},
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        status: ContentStatus.active,
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.draft,
      isBreaking: false,
      lastEnrichedAt: null,
    );

    // Default Topic Repo Mock
    when(
      () => mockTopicRepo.readAll(
        filter: any(named: 'filter'),
        pagination: any(named: 'pagination'),
      ),
    ).thenAnswer(
      (_) async =>
          const PaginatedResponse(items: [], cursor: null, hasMore: false),
    );

    // Default Usage Repo Mock
    when(() => mockUsageRepo.read(id: any(named: 'id'))).thenAnswer(
      (_) async => AiUsage(
        id: 'usage',
        tokenUsage: 0,
        requestCount: 0,
        updatedAt: DateTime.now(),
      ),
    );
    when(
      () => mockUsageRepo.update(
        id: any(named: 'id'),
        item: any(named: 'item'),
      ),
    ).thenAnswer((_) async => FakeAiUsage());
    when(
      () => mockUsageRepo.create(item: any(named: 'item')),
    ).thenAnswer((_) async => FakeAiUsage());
  });

  group('IntelligenceService', () {
    test('Guard: throws OperationFailedException if AI disabled', () async {
      EnvironmentConfig.setOverride('AI_INGESTION_ENABLED', 'false');
      expect(
        () => service.execute(strategy: FakeAiStrategy(), input: 'test'),
        throwsA(isA<OperationFailedException>()),
      );
    });

    test('Quota: throws ForbiddenException if limit exceeded', () async {
      when(() => mockUsageRepo.read(id: any(named: 'id'))).thenAnswer(
        (_) async => AiUsage(
          id: 'usage',
          tokenUsage: 1001, // Exceeds 1000
          requestCount: 1,
          updatedAt: DateTime.now(),
        ),
      );
      expect(
        () => service.execute(strategy: FakeAiStrategy(), input: 'test'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('Success: calls client and records usage', () async {
      when(
        () => mockClient.generateCompletion(
          messages: any(named: 'messages'),
          temperature: any(named: 'temperature'),
          maxTokens: any(named: 'maxTokens'),
        ),
      ).thenAnswer(
        (_) async => (data: {'result': 'success'}, totalTokens: 100),
      );

      final result = await service.execute(
        strategy: FakeAiStrategy(),
        input: 'test',
      );

      expect(result, 'success');
      verify(
        () => mockUsageRepo.create(
          item: any(
            named: 'item',
            that: isA<AiUsage>().having((u) => u.tokenUsage, 'tokenUsage', 100),
          ),
        ),
      ).called(1);
    });
  });

  group('IntelligenceService.run (Worker)', () {
    setUp(() {
      // Default mocks for cache warming
      when(
        () => mockCountryRepo.readAll(pagination: any(named: 'pagination')),
      ).thenAnswer(
        (_) async =>
            const PaginatedResponse(items: [], cursor: null, hasMore: false),
      );
      when(
        () => mockTopicRepo.readAll(pagination: any(named: 'pagination')),
      ).thenAnswer(
        (_) async =>
            const PaginatedResponse(items: [], cursor: null, hasMore: false),
      );
    });

    test('processes drafts and activates them', () async {
      // Arrange: Return 1 draft, then empty to stop loop
      final responses = <PaginatedResponse<Headline>>[
        PaginatedResponse(
          items: [draftHeadline],
          cursor: 'next',
          hasMore: true,
        ),
        const PaginatedResponse(items: [], cursor: null, hasMore: false),
      ];
      when(
        () => mockHeadlineRepo.readAll(
          filter: {
            'status': ContentStatus.draft.name,
            'lastEnrichedAt': null,
          },
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer((_) async => responses.removeAt(0));

      // Arrange: AI Response
      final aiResponseData = {
        draftHeadline.id: {
          'isNews': true,
          'topicSlug': 'Technology',
          'extractedPersons': [
            {
              'name': {'en': 'Elon Musk'},
              'description': {'en': 'Tech Entrepreneur'},
            },
          ],
          'extractedCountryCodes': ['US'],
          'breakingConfidence': 0.9,
          'translations': {'es': 'Titulo'},
        },
      };

      when(
        () => mockClient.generateCompletion(
          messages: any(named: 'messages'),
          temperature: any(named: 'temperature'),
          maxTokens: any(named: 'maxTokens'),
        ),
      ).thenAnswer(
        (_) async => (data: aiResponseData, totalTokens: 50),
      );

      // Arrange: Identity Resolution
      when(
        () => mockIdentityService.resolvePersons(
          any(),
        ),
      ).thenAnswer(
        (_) async => (
          persons: [const Person(id: 'p1', name: {}, description: {})],
          createdCount: 0,
          reusedCount: 1,
        ),
      );

      // Arrange: Updates
      when(
        () => mockHeadlineRepo.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      ).thenAnswer((_) async => draftHeadline); // Return anything, ignored

      // Arrange: Notifications
      when(
        () => mockPushService.sendBreakingNewsNotification(
          headline: any(named: 'headline'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await service.run();

      // Assert: Headline updated to active
      verify(
        () => mockHeadlineRepo.update(
          id: draftHeadline.id,
          item: any(
            named: 'item',
            that: isA<Headline>()
                .having((h) => h.lastEnrichedAt, 'lastEnrichedAt', isNotNull)
                .having((h) => h.isBreaking, 'isBreaking', true),
          ),
        ),
      ).called(1);

      // Assert: Notification sent
      verify(
        () => mockPushService.sendBreakingNewsNotification(
          headline: any(named: 'headline'),
        ),
      ).called(1);
    });

    test('hard deletes junk content', () async {
      // Arrange: Return 1 draft
      final responses = <PaginatedResponse<Headline>>[
        PaginatedResponse(
          items: [draftHeadline],
          cursor: 'next',
          hasMore: true,
        ),
        const PaginatedResponse(items: [], cursor: null, hasMore: false),
      ];
      when(
        () => mockHeadlineRepo.readAll(
          filter: {
            'status': ContentStatus.draft.name,
            'lastEnrichedAt': null,
          },
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer((_) async => responses.removeAt(0));

      // Arrange: AI says not news
      final aiResponseData = {
        draftHeadline.id: {
          'isNews': false, // JUNK
          'topicSlug': null,
          'extractedPersons': [],
          'extractedCountryCodes': [],
          'breakingConfidence': 0.0,
          'translations': {},
        },
      };

      when(
        () => mockClient.generateCompletion(
          messages: any(named: 'messages'),
        ),
      ).thenAnswer(
        (_) async => (data: aiResponseData, totalTokens: 10),
      );

      // Arrange: Update mock
      when(
        () => mockHeadlineRepo.delete(id: any(named: 'id')),
      ).thenAnswer((_) async {});

      // Act
      await service.run();

      // Assert: Purged from DB
      verify(() => mockHeadlineRepo.delete(id: draftHeadline.id)).called(1);
      verifyNever(
        () => mockHeadlineRepo.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      );

      // Assert: No notification
      verifyNever(
        () => mockPushService.sendBreakingNewsNotification(
          headline: any(named: 'headline'),
        ),
      );
    });

    test('stops when no drafts found', () async {
      when(
        () => mockHeadlineRepo.readAll(
          filter: {
            'status': ContentStatus.draft.name,
            'lastEnrichedAt': null,
          },
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer(
        (_) async =>
            const PaginatedResponse(items: [], cursor: null, hasMore: false),
      );

      await service.run();

      verify(
        () => mockHeadlineRepo.readAll(
          filter: {
            'status': ContentStatus.draft.name,
            'lastEnrichedAt': null,
          },
          pagination: any(named: 'pagination'),
        ),
      ).called(1);
      verifyNever(
        () => mockClient.generateCompletion(messages: any(named: 'messages')),
      );
    });
  });
}
