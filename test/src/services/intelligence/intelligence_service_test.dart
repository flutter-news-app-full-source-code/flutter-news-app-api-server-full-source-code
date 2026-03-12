import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:verity_api/src/clients/intelligence/intelligence_client.dart';
import 'package:verity_api/src/config/environment_config.dart';
import 'package:verity_api/src/models/intelligence/ai_usage.dart';
import 'package:verity_api/src/services/intelligence/intelligence_service.dart';
import 'package:verity_api/src/services/intelligence/strategies/ai_strategy.dart';

class MockIntelligenceClient extends Mock implements IntelligenceClient {}

class MockUsageRepository extends Mock implements DataRepository<AiUsage> {}

class MockTopicRepository extends Mock implements DataRepository<Topic> {}

class MockRemoteConfigRepository extends Mock
    implements DataRepository<RemoteConfig> {}

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
  String mapResponse(Map<String, dynamic> data, String input) {
    return data['result'] as String;
  }
}

void main() {
  late IntelligenceService service;
  late MockIntelligenceClient mockClient;
  late MockUsageRepository mockUsageRepo;
  late MockTopicRepository mockTopicRepo;
  late MockRemoteConfigRepository mockRemoteConfigRepo;
  late MockLogger mockLogger;

  setUp(() {
    mockClient = MockIntelligenceClient();
    mockUsageRepo = MockUsageRepository();
    mockTopicRepo = MockTopicRepository();
    mockRemoteConfigRepo = MockRemoteConfigRepository();
    mockLogger = MockLogger();

    registerFallbackValue(FakeAiUsage());

    service = IntelligenceService(
      client: mockClient,
      usageRepository: mockUsageRepo,
      topicRepository: mockTopicRepo,
      remoteConfigRepository: mockRemoteConfigRepo,
      log: mockLogger,
    );

    // Default Config Overrides
    EnvironmentConfig.setOverride('AI_INGESTION_ENABLED', 'true');
    EnvironmentConfig.setOverride('AI_DAILY_TOKEN_QUOTA', '1000');

    // Default RemoteConfig Mock
    when(() => mockRemoteConfigRepo.read(id: any(named: 'id'))).thenAnswer(
      (_) async => RemoteConfig(
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
}

class FakeAiUsage extends Fake implements AiUsage {}
