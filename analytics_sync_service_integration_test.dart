import 'package:core/core.dart';
import 'package:data_client/data_client.dart';
import 'package:data_mongodb/data_mongodb.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/analytics/analytics.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';

class MockAnalyticsReportingClient extends Mock
    implements AnalyticsReportingClient {}

/// A test-specific subclass of AnalyticsSyncService that allows injecting
/// mocked clients.
class TestableAnalyticsSyncService extends AnalyticsSyncService {
  TestableAnalyticsSyncService({
    required super.remoteConfigRepository,
    required super.kpiCardRepository,
    required super.chartCardRepository,
    required super.rankedListCardRepository,
    required super.userRepository,
    required super.topicRepository,
    required super.reportRepository,
    required super.sourceRepository,
    required super.headlineRepository,
    required super.engagementRepository,
    required super.appReviewRepository,
    required super.analyticsMetricMapper,
    required super.log,
    required AnalyticsReportingClient? testAnalyticsClient,
  }) : super(
         googleAnalyticsClient: testAnalyticsClient,
         mixpanelClient: testAnalyticsClient,
       );
}

void main() {
  group('AnalyticsSyncService Integration Test', () {
    late MongoDbConnectionManager mongoDbConnectionManager;
    late DataRepository<RemoteConfig> remoteConfigRepository;
    late DataRepository<KpiCardData> kpiCardRepository;
    late DataRepository<ChartCardData> chartCardRepository;
    late DataRepository<RankedListCardData> rankedListCardRepository;
    late DataRepository<Topic> topicRepository;
    late TestableAnalyticsSyncService service;
    late MockAnalyticsReportingClient mockAnalyticsClient;

    setUpAll(() async {
      mongoDbConnectionManager = MongoDbConnectionManager();
      await mongoDbConnectionManager.init(EnvironmentConfig.testDatabaseUrl);

      // Initialize repositories with real database clients
      remoteConfigRepository = DataRepository(
        dataClient: DataMongodb<RemoteConfig>(
          connectionManager: mongoDbConnectionManager,
          modelName: 'remote_configs',
          fromJson: RemoteConfig.fromJson,
          toJson: (i) => i.toJson(),
        ),
      );
      kpiCardRepository = DataRepository(
        dataClient: DataMongodb<KpiCardData>(
          connectionManager: mongoDbConnectionManager,
          modelName: 'kpi_card_data',
          fromJson: KpiCardData.fromJson,
          toJson: (i) => i.toJson(),
        ),
      );
      chartCardRepository = DataRepository(
        dataClient: DataMongodb<ChartCardData>(
          connectionManager: mongoDbConnectionManager,
          modelName: 'chart_card_data',
          fromJson: ChartCardData.fromJson,
          toJson: (i) => i.toJson(),
        ),
      );
      rankedListCardRepository = DataRepository(
        dataClient: DataMongodb<RankedListCardData>(
          connectionManager: mongoDbConnectionManager,
          modelName: 'ranked_list_card_data',
          fromJson: RankedListCardData.fromJson,
          toJson: (i) => i.toJson(),
        ),
      );
      topicRepository = DataRepository(
        dataClient: DataMongodb<Topic>(
          connectionManager: mongoDbConnectionManager,
          modelName: 'topics',
          fromJson: Topic.fromJson,
          toJson: (i) => i.toJson(),
        ),
      );
    });

    tearDownAll(() async {
      await mongoDbConnectionManager.close();
    });

    setUp(() async {
      mockAnalyticsClient = MockAnalyticsReportingClient();

      // Clean up collections before each test
      await mongoDbConnectionManager.db
          .collection('remote_configs')
          .deleteMany(
            <String, dynamic>{},
          );
      await mongoDbConnectionManager.db
          .collection('kpi_card_data')
          .deleteMany(
            <String, dynamic>{},
          );
      await mongoDbConnectionManager.db
          .collection('chart_card_data')
          .deleteMany(
            <String, dynamic>{},
          );
      await mongoDbConnectionManager.db
          .collection('ranked_list_card_data')
          .deleteMany(
            <String, dynamic>{},
          );
      await mongoDbConnectionManager.db
          .collection('topics')
          .deleteMany(<String, dynamic>{});

      // Register fallback values
      registerFallbackValue(
        const EventCountQuery(event: AnalyticsEvent.adClicked),
      );
      registerFallbackValue(DateTime.now());

      service = TestableAnalyticsSyncService(
        remoteConfigRepository: remoteConfigRepository,
        kpiCardRepository: kpiCardRepository,
        chartCardRepository: chartCardRepository,
        rankedListCardRepository: rankedListCardRepository,
        // Provide dummy repositories for unused dependencies
        userRepository: DataRepository(dataClient: MockDataClient<User>()),
        topicRepository: topicRepository,
        reportRepository: DataRepository(dataClient: MockDataClient<Report>()),
        sourceRepository: DataRepository(dataClient: MockDataClient<Source>()),
        headlineRepository: DataRepository(
          dataClient: MockDataClient<Headline>(),
        ),
        engagementRepository: DataRepository(
          dataClient: MockDataClient<Engagement>(),
        ),
        appReviewRepository: DataRepository(
          dataClient: MockDataClient<AppReview>(),
        ),
        analyticsMetricMapper: AnalyticsMetricMapper(),
        log: Logger('TestAnalyticsSyncService'),
        testAnalyticsClient: mockAnalyticsClient,
      );
    });

    test(
      'run syncs provider-driven KPI card and persists result in database',
      () async {
        // 1. Setup: Seed remote config and mock the external client response
        await remoteConfigRepository.create(
          item: remoteConfigsFixturesData.first,
        );

        when(
          () => mockAnalyticsClient.getMetricTotal(any(), any(), any()),
        ).thenAnswer((_) async => 150); // Current period

        // 2. Execute: Run the service
        await service.run();

        // 3. Assert: Verify the data was correctly processed and saved
        final kpiCard = await kpiCardRepository.read(
          id: KpiCardId.usersActiveUsers.name,
        );

        expect(kpiCard, isNotNull);
        expect(kpiCard.id, KpiCardId.usersActiveUsers);
        expect(kpiCard.timeFrames[KpiTimeFrame.day]!.value, 150);
        expect(kpiCard.timeFrames[KpiTimeFrame.day]!.trend, '+0.0%');
      },
    );

    test(
      'run syncs database-driven ranked list and persists result in database',
      () async {
        // 1. Setup: Seed remote config and seed the database with fixture data
        await remoteConfigRepository.create(
          item: remoteConfigsFixturesData.first,
        );

        // Seed raw maps directly into the database to simulate documents
        // with the `followerIds` field, which is not part of the core Topic model.
        final topicDocuments = [
          {
            '_id': ObjectId(),
            'name': 'Tech',
            'description': '',
            'iconUrl': '',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'status': 'active',
            'followerIds': ['user1', 'user2', 'user3'],
          },
          {
            '_id': ObjectId(),
            'name': 'Sports',
            'description': '',
            'iconUrl': '',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'status': 'active',
            'followerIds': ['user1'],
          },
        ];

        for (final doc in topicDocuments) {
          await mongoDbConnectionManager.db.collection('topics').insertOne(doc);
        }

        // 2. Execute: Run the service
        await service.run();

        // 3. Assert: Verify the ranked list was correctly aggregated and saved
        final rankedListCard = await rankedListCardRepository.read(
          id: RankedListCardId.overviewTopicsMostFollowed.name,
        );

        expect(rankedListCard, isNotNull);
        final dayTimeFrame = rankedListCard.timeFrames[RankedListTimeFrame.day];
        expect(dayTimeFrame, isNotNull);
        expect(dayTimeFrame, hasLength(2));
        expect(dayTimeFrame!.first.displayTitle, 'Tech');
        expect(dayTimeFrame.first.metricValue, 3);
        expect(dayTimeFrame.last.displayTitle, 'Sports');
        expect(dayTimeFrame.last.metricValue, 1);
      },
    );
  });
}

class MockDataClient<T> extends Mock implements DataClient<T> {}
