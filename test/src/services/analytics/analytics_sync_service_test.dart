import 'package:core/core.dart';

import 'package:flutter_news_app_backend_api_full_source_code/src/clients/analytics/analytics_reporting_client.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/models.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/analytics/analytics.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:test/test.dart';

// Mocks for all dependencies of AnalyticsSyncService
class MockDataRepository<T> extends Mock implements DataRepository<T> {}

class MockAnalyticsReportingClient extends Mock
    implements AnalyticsReportingClient {}

class MockAnalyticsMetricMapper extends Mock implements AnalyticsMetricMapper {}

void main() {
  group('AnalyticsSyncService', () {
    late AnalyticsSyncService service;
    late MockDataRepository<RemoteConfig> mockRemoteConfigRepo;
    late MockDataRepository<KpiCardData> mockKpiCardRepo;
    late MockDataRepository<ChartCardData> mockChartCardRepo;
    late MockDataRepository<RankedListCardData> mockRankedListCardRepo;
    late MockAnalyticsReportingClient mockAnalyticsClient;
    late MockAnalyticsMetricMapper mockMapper;

    // Other repositories that are dependencies but may not be used in all tests
    late MockDataRepository<User> mockUserRepo;
    late MockDataRepository<Topic> mockTopicRepo;
    late MockDataRepository<Report> mockReportRepo;
    late MockDataRepository<Source> mockSourceRepo;
    late MockDataRepository<Headline> mockHeadlineRepo;
    late MockDataRepository<Engagement> mockEngagementRepo;
    late MockDataRepository<AppReview> mockAppReviewRepo;
    late MockDataRepository<UserRewards> mockUserRewardsRepo;
    late MockDataRepository<MediaAsset> mockMediaAssetRepo;

    setUp(() {
      mockRemoteConfigRepo = MockDataRepository<RemoteConfig>();
      mockKpiCardRepo = MockDataRepository<KpiCardData>();
      mockChartCardRepo = MockDataRepository<ChartCardData>();
      mockRankedListCardRepo = MockDataRepository<RankedListCardData>();
      mockAnalyticsClient = MockAnalyticsReportingClient();
      mockMapper = MockAnalyticsMetricMapper();

      mockUserRepo = MockDataRepository<User>();
      mockTopicRepo = MockDataRepository<Topic>();
      mockReportRepo = MockDataRepository<Report>();
      mockSourceRepo = MockDataRepository<Source>();
      mockHeadlineRepo = MockDataRepository<Headline>();
      mockEngagementRepo = MockDataRepository<Engagement>();
      mockAppReviewRepo = MockDataRepository<AppReview>();
      mockUserRewardsRepo = MockDataRepository<UserRewards>();
      mockMediaAssetRepo = MockDataRepository<MediaAsset>();

      // Register fallback values for any() matchers
      registerFallbackValue(
        const EventCountQuery(event: AnalyticsEvent.adClicked),
      );
      registerFallbackValue(DateTime.now());
      registerFallbackValue(KpiCardId.usersTotalRegistered);
      registerFallbackValue(
        const KpiCardData(
          id: 'fallback_id',
          cardId: KpiCardId.usersTotalRegistered,
          label: {SupportedLanguage.en: ''},
          timeFrames: {},
        ),
      );
      registerFallbackValue(
        const ChartCardData(
          id: 'fallback_id',
          cardId: ChartCardId.contentHeadlinesViewsByTopic,
          label: {SupportedLanguage.en: ''},
          type: ChartType.bar,
          timeFrames: {},
        ),
      );
      registerFallbackValue(
        const RankedListCardData(
          id: 'fallback_id',
          cardId: RankedListCardId.overviewTopicsMostFollowed,
          label: {SupportedLanguage.en: ''},
          timeFrames: {},
        ),
      );

      service = AnalyticsSyncService(
        remoteConfigRepository: mockRemoteConfigRepo,
        kpiCardRepository: mockKpiCardRepo,
        chartCardRepository: mockChartCardRepo,
        rankedListCardRepository: mockRankedListCardRepo,
        userRepository: mockUserRepo,
        topicRepository: mockTopicRepo,
        reportRepository: mockReportRepo,
        sourceRepository: mockSourceRepo,
        headlineRepository: mockHeadlineRepo,
        engagementRepository: mockEngagementRepo,
        appReviewRepository: mockAppReviewRepo,
        userRewardsRepository: mockUserRewardsRepo,
        mediaAssetRepository: mockMediaAssetRepo,
        googleAnalyticsClient: mockAnalyticsClient,
        mixpanelClient: mockAnalyticsClient,
        analyticsMetricMapper: mockMapper,
        log: Logger('TestAnalyticsSyncService'),
      );
    });

    // Helper to create a default remote config
    RemoteConfig createRemoteConfig({
      bool analyticsEnabled = true,
      AnalyticsProviders provider = AnalyticsProviders.mixpanel,
    }) {
      return RemoteConfig(
        id: 'test',
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
        features: FeaturesConfig(
          onboarding: const OnboardingConfig(
            isEnabled: true,
            appTour: AppTourConfig(
              isEnabled: true,
              isSkippable: true,
            ),
            initialPersonalization: InitialPersonalizationConfig(
              isEnabled: true,
              isCountrySelectionEnabled: true,
              isTopicSelectionEnabled: true,
              isSourceSelectionEnabled: true,
              isSkippable: true,
            ),
          ),
          ads: const AdConfig(
            enabled: false,
            primaryAdPlatform: AdPlatformType.admob,
            platformAdIdentifiers: {},
            feedAdConfiguration: FeedAdConfiguration(
              enabled: false,
              adType: AdType.banner,
              visibleTo: {},
            ),
            navigationAdConfiguration: NavigationAdConfiguration(
              enabled: false,
              visibleTo: {},
            ),
          ),
          analytics: AnalyticsConfig(
            enabled: analyticsEnabled,
            activeProvider: provider,
            disabledEvents: const {},
            eventSamplingRates: const {},
          ),
          pushNotifications: const PushNotificationConfig(
            enabled: false,
            primaryProvider: PushNotificationProviders.firebase,
            deliveryConfigs: {},
          ),
          feed: const FeedConfig(
            itemClickBehavior: FeedItemClickBehavior.internalNavigation,
            decorators: {},
          ),
          community: const CommunityConfig(
            enabled: false,
            engagement: EngagementConfig(
              enabled: false,
              engagementMode: EngagementMode.reactionsOnly,
            ),
            reporting: ReportingConfig(
              enabled: false,
              headlineReportingEnabled: false,
              sourceReportingEnabled: false,
              commentReportingEnabled: false,
            ),
            appReview: AppReviewConfig(
              enabled: false,
              interactionCycleThreshold: 0,
              initialPromptCooldownDays: 0,
              eligiblePositiveInteractions: [],
              isNegativeFeedbackFollowUpEnabled: false,
              isPositiveFeedbackFollowUpEnabled: false,
            ),
          ),
          rewards: const RewardsConfig(enabled: true, rewards: {}),
        ),
        user: const UserConfig(
          limits: UserLimitsConfig(
            followedItems: {},
            savedHeadlines: {},
            savedHeadlineFilters: {},
            commentsPerDay: {},
            reactionsPerDay: {},
            reportsPerDay: {},
          ),
        ),
      );
    }

    test('run skips sync if analytics is disabled in remote config', () async {
      final config = createRemoteConfig(analyticsEnabled: false);
      when(
        () => mockRemoteConfigRepo.read(id: any(named: 'id')),
      ).thenAnswer((_) async => config);

      await service.run();

      verifyNever(() => mockMapper.getKpiQuery(any()));
    });

    test('run syncs KPI card correctly', () async {
      final config = createRemoteConfig();
      const kpiId = KpiCardId.usersTotalRegistered;
      const query = EventCountQuery(event: AnalyticsEvent.userRegistered);

      when(
        () => mockRemoteConfigRepo.read(id: any(named: 'id')),
      ).thenAnswer((_) async => config);
      when(() => mockMapper.getKpiQuery(kpiId)).thenReturn(query);

      // Mock the batch call instead of the singular call
      when(
        () => mockAnalyticsClient.getMetricTotalsBatch(any(), any()),
      ).thenAnswer((invocation) async {
        final ranges =
            invocation.positionalArguments[1] as List<GARequestDateRange>;
        return {
          for (final range in ranges) range: 100,
        };
      });

      // Mock readAll to return an existing card so update is called
      when(
        () => mockKpiCardRepo.readAll(
          filter: any(named: 'filter'),
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer(
        (_) async => const PaginatedResponse(
          items: [
            KpiCardData(
              id: 'test_id',
              cardId: kpiId,
              label: {SupportedLanguage.en: ''},
              timeFrames: {},
            ),
          ],
          cursor: null,
          hasMore: false,
        ),
      );

      when(
        () => mockKpiCardRepo.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      ).thenAnswer(
        (_) async => const KpiCardData(
          id: 'test_id',
          cardId: kpiId,
          label: {SupportedLanguage.en: ''},
          timeFrames: {},
        ),
      );

      await service.run();

      // Verify that getMetricTotalsBatch was called once with the query
      verify(
        () => mockAnalyticsClient.getMetricTotalsBatch(query, any()),
      ).called(1);

      // Verify that the repository update was called with the correct data
      final captured = verify(
        () => mockKpiCardRepo.update(
          id: 'test_id',
          item: captureAny(named: 'item'),
        ),
      ).captured;

      final capturedCard = captured.first as KpiCardData;
      expect(capturedCard.cardId, kpiId);
      expect(capturedCard.timeFrames[KpiTimeFrame.day]!.value, 100);
      // 100 vs 100 -> 0% trend
      expect(capturedCard.timeFrames[KpiTimeFrame.day]!.trend, '+0.0%');
    });

    test(
      'run syncs Database Chart card with localized labels correctly',
      () async {
        final config = createRemoteConfig();
        const chartId = ChartCardId.contentHeadlinesViewsByTopic;
        const query = StandardMetricQuery(
          metric: 'database:headlines:viewsByTopic',
        );

        when(
          () => mockRemoteConfigRepo.read(id: any(named: 'id')),
        ).thenAnswer((_) async => config);

        // Mock Mapper to return our query for this chart
        when(() => mockMapper.getChartQuery(chartId)).thenReturn(query);
        when(() => mockMapper.getChartType(chartId)).thenReturn(ChartType.bar);

        // Mock existing card to trigger update path
        when(
          () => mockChartCardRepo.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedResponse(
            items: [
              ChartCardData(
                id: 'chart_id',
                cardId: chartId,
                label: {SupportedLanguage.en: 'Views by Topic'},
                type: ChartType.bar,
                timeFrames: {},
              ),
            ],
            cursor: null,
            hasMore: false,
          ),
        );

        // Mock Aggregation Result from Headline Repo
        // This simulates MongoDB returning a Map for the grouped field (topic.name)
        final aggregationResult = [
          {
            'label': {'en': 'Technology', 'es': 'Tecnología'},
            'value': 42,
          },
        ];

        when(
          () => mockHeadlineRepo.aggregate(pipeline: any(named: 'pipeline')),
        ).thenAnswer((_) async => aggregationResult);

        // Mock Update
        when(
          () => mockChartCardRepo.update(
            id: any(named: 'id'),
            item: any(named: 'item'),
          ),
        ).thenAnswer(
          (invocation) async =>
              invocation.namedArguments[#item] as ChartCardData,
        );

        await service.run();

        // Verify
        final captured = verify(
          () => mockChartCardRepo.update(
            id: 'chart_id',
            item: captureAny(named: 'item'),
          ),
        ).captured;

        final updatedCard = captured.first as ChartCardData;
        final dataPoints =
            updatedCard.timeFrames[ChartTimeFrame.week]!; // Default check

        expect(dataPoints.first.value, 42);
        expect(dataPoints.first.label![SupportedLanguage.en], 'Technology');
        expect(dataPoints.first.label![SupportedLanguage.es], 'Tecnología');
      },
    );

    test(
      'run syncs Database Chart card with String labels (fallback) correctly',
      () async {
        final config = createRemoteConfig();
        const chartId = ChartCardId.contentHeadlinesViewsByTopic;
        const query = StandardMetricQuery(
          metric: 'database:headlines:viewsByTopic',
        );

        when(
          () => mockRemoteConfigRepo.read(id: any(named: 'id')),
        ).thenAnswer((_) async => config);

        when(() => mockMapper.getChartQuery(chartId)).thenReturn(query);
        when(() => mockMapper.getChartType(chartId)).thenReturn(ChartType.bar);

        when(
          () => mockChartCardRepo.readAll(
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

        when(
          () => mockChartCardRepo.create(item: any(named: 'item')),
        ).thenAnswer(
          (invocation) async =>
              invocation.namedArguments[#item] as ChartCardData,
        );

        // Mock Aggregation Result with String label (e.g. a date or enum)
        final aggregationResult = [
          {
            'label': 'someCategory',
            'value': 10,
          },
        ];

        when(
          () => mockHeadlineRepo.aggregate(pipeline: any(named: 'pipeline')),
        ).thenAnswer((_) async => aggregationResult);

        await service.run();

        final captured = verify(
          () => mockChartCardRepo.create(
            item: captureAny(named: 'item'),
          ),
        ).captured;

        final createdCard = captured.first as ChartCardData;
        final dataPoints = createdCard.timeFrames[ChartTimeFrame.week]!;

        expect(dataPoints.first.value, 10);
        // Verify fallback formatting logic (camelCase -> Title Case)
        expect(dataPoints.first.label![SupportedLanguage.en], 'Some Category');
      },
    );

    test(
      'run syncs Database Ranked List with localized titles correctly',
      () async {
        final config = createRemoteConfig();
        const rankedListId = RankedListCardId.overviewTopicsMostFollowed;
        const query = StandardMetricQuery(
          metric: 'database:topics:byFollowers',
        );

        when(
          () => mockRemoteConfigRepo.read(id: any(named: 'id')),
        ).thenAnswer((_) async => config);

        when(
          () => mockMapper.getRankedListQuery(rankedListId),
        ).thenReturn(query);

        when(
          () => mockRankedListCardRepo.readAll(
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

        when(
          () => mockRankedListCardRepo.create(item: any(named: 'item')),
        ).thenAnswer(
          (invocation) async =>
              invocation.namedArguments[#item] as RankedListCardData,
        );

        // Mock Aggregation Result with Map displayTitle
        final aggregationResult = [
          {
            'entityId': ObjectId(),
            'displayTitle': {'en': 'Tech', 'es': 'Tecnología'},
            'metricValue': 100,
          },
        ];

        when(
          () => mockTopicRepo.aggregate(pipeline: any(named: 'pipeline')),
        ).thenAnswer((_) async => aggregationResult);

        await service.run();

        final captured = verify(
          () => mockRankedListCardRepo.create(
            item: captureAny(named: 'item'),
          ),
        ).captured;

        final createdCard = captured.first as RankedListCardData;
        final items = createdCard.timeFrames[RankedListTimeFrame.week]!;

        expect(items.first.metricValue, 100);
        expect(items.first.displayTitle[SupportedLanguage.en], 'Tech');
        expect(items.first.displayTitle[SupportedLanguage.es], 'Tecnología');
      },
    );
  });
}
