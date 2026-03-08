import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';
import 'package:verity_api/src/config/environment_config.dart';
import 'package:verity_api/src/models/ingestion/aggregator_type.dart';
import 'package:verity_api/src/models/ingestion/ingestion_topic_mapping.dart';
import 'package:verity_api/src/models/ingestion/ingestion_usage.dart';
import 'package:verity_api/src/services/idempotency_service.dart';
import 'package:verity_api/src/services/ingestion/news_ingestion_service.dart';
import 'package:verity_api/src/services/ingestion/providers/aggregator_provider.dart';
import 'package:verity_api/src/services/ingestion/registries/aggregator_registry.dart';

class MockDataRepository<T> extends Mock implements DataRepository<T> {}

class MockAggregatorRegistry extends Mock implements AggregatorRegistry {}

class MockAggregatorProvider extends Mock implements AggregatorProvider {}

class MockIdempotencyService extends Mock implements IdempotencyService {}

class MockLogger extends Mock implements Logger {}

class FakeSource extends Fake implements Source {}

class FakeTopic extends Fake implements Topic {}

class FakeIngestionUsage extends Fake implements IngestionUsage {}

class FakeHeadline extends Fake implements Headline {}

class FakeNewsAutomationTask extends Fake implements NewsAutomationTask {}

void main() {
  late NewsIngestionService service;
  late MockDataRepository<NewsAutomationTask> mockTaskRepo;
  late MockDataRepository<Headline> mockHeadlineRepo;
  late MockDataRepository<Source> mockSourceRepo;
  late MockDataRepository<Topic> mockTopicRepo;
  late MockDataRepository<Country> mockCountryRepo;
  late MockDataRepository<IngestionTopicMapping> mockMappingRepo;
  late MockDataRepository<IngestionUsage> mockUsageRepo;
  late MockAggregatorRegistry mockRegistry;
  late MockIdempotencyService mockIdempotency;
  late MockLogger mockLogger;
  late MockAggregatorProvider mockProvider;

  late Topic generalTopic;
  late Country usCountry;
  late Source source;
  late NewsAutomationTask task;

  setUpAll(() {
    registerFallbackValue(AggregatorType.newsApi);
    registerFallbackValue(FakeSource());
    registerFallbackValue(FakeTopic());
    registerFallbackValue(FakeIngestionUsage());
    registerFallbackValue(FakeHeadline());
    registerFallbackValue(FakeNewsAutomationTask());
  });

  setUp(() {
    mockTaskRepo = MockDataRepository<NewsAutomationTask>();
    mockHeadlineRepo = MockDataRepository<Headline>();
    mockSourceRepo = MockDataRepository<Source>();
    mockTopicRepo = MockDataRepository<Topic>();
    mockCountryRepo = MockDataRepository<Country>();
    mockMappingRepo = MockDataRepository<IngestionTopicMapping>();
    mockUsageRepo = MockDataRepository<IngestionUsage>();
    mockRegistry = MockAggregatorRegistry();
    mockIdempotency = MockIdempotencyService();
    mockLogger = MockLogger();
    mockProvider = MockAggregatorProvider();

    service = NewsIngestionService(
      taskRepository: mockTaskRepo,
      headlineRepository: mockHeadlineRepo,
      sourceRepository: mockSourceRepo,
      topicRepository: mockTopicRepo,
      countryRepository: mockCountryRepo,
      mappingRepository: mockMappingRepo,
      usageRepository: mockUsageRepo,
      aggregatorRegistry: mockRegistry,
      idempotencyService: mockIdempotency,
      log: mockLogger,
    );

    // Setup default environment overrides
    EnvironmentConfig.setOverride('INGESTION_DAILY_QUOTA', '100');
    EnvironmentConfig.setOverride('AGGREGATOR_PROVIDER', 'newsApi');
    EnvironmentConfig.setOverride('INGESTION_REQUEST_DELAY_SECONDS', '0');

    // Setup default entities
    generalTopic = Topic(
      id: 'topic-general',
      name: const {SupportedLanguage.en: 'General'},
      description: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
    );

    usCountry = const Country(
      id: 'country-us',
      isoCode: 'US',
      name: {},
      flagUrl: '',
    );

    source = Source(
      id: 'source-1',
      name: const {},
      description: const {},
      url: 'https://example.com',
      sourceType: SourceType.newsAgency,
      language: SupportedLanguage.en,
      headquarters: usCountry,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
    );

    task = NewsAutomationTask(
      id: 'task-1',
      sourceId: source.id,
      fetchInterval: FetchInterval.hourly,
      status: IngestionStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      nextRunAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );

    // Default mock behaviors for cache warming
    when(
      () => mockTopicRepo.readAll(pagination: any(named: 'pagination')),
    ).thenAnswer(
      (_) async => PaginatedResponse(
        items: [generalTopic],
        cursor: null,
        hasMore: false,
      ),
    );
    when(
      () => mockCountryRepo.readAll(pagination: any(named: 'pagination')),
    ).thenAnswer(
      (_) async => PaginatedResponse(
        items: [usCountry],
        cursor: null,
        hasMore: false,
      ),
    );
    when(
      () => mockMappingRepo.readAll(pagination: any(named: 'pagination')),
    ).thenAnswer(
      (_) async =>
          const PaginatedResponse(items: [], cursor: null, hasMore: false),
    );

    // Default quota check (not exceeded)
    when(() => mockUsageRepo.read(id: any(named: 'id'))).thenAnswer(
      (_) async => IngestionUsage(
        id: 'today',
        requestCount: 0,
        updatedAt: DateTime.now(),
      ),
    );

    // Default registry behavior
    when(() => mockRegistry.getProvider(any())).thenReturn(mockProvider);
  });

  group('NewsIngestionService', () {
    test('aborts run if daily quota is exceeded', () async {
      // Arrange: Quota exceeded
      when(() => mockUsageRepo.read(id: any(named: 'id'))).thenAnswer(
        (_) async => IngestionUsage(
          id: 'today',
          requestCount: 100,
          updatedAt: DateTime.now(),
        ),
      );

      // Act
      await service.run();

      // Assert: No tasks should be claimed
      verifyNever(() => mockTaskRepo.readAll(filter: any(named: 'filter')));
      verify(
        () => mockLogger.warning(
          'Daily ingestion quota exceeded. Aborting cycle to prevent overage.',
        ),
      ).called(1);
    });

    test('claims and processes tasks successfully', () async {
      // Arrange: 1 pending task
      when(
        () => mockTaskRepo.readAll(filter: any(named: 'filter')),
      ).thenAnswer(
        (_) async =>
            PaginatedResponse(items: [task], cursor: null, hasMore: false),
      );

      // Arrange: Lock acquisition successful
      when(
        () => mockIdempotency.recordEvent(any(), scope: any(named: 'scope')),
      ).thenAnswer((_) async {});

      // Arrange: Source fetch
      when(
        () => mockSourceRepo.read(id: source.id),
      ).thenAnswer((_) async => source);

      // Arrange: Provider returns 1 headline
      final headline = Headline(
        // Note: Using ObjectId().oid to ensure valid ID
        id: ObjectId().oid,
        title: const {SupportedLanguage.en: 'Test Headline'},
        url: 'https://example.com/1',
        imageUrl: '',
        source: source,
        eventCountry: usCountry,
        topic: generalTopic,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
        isBreaking: false,
      );
      when(
        () => mockProvider.fetchLatestHeadlines(
          any(),
          topicCache: any(named: 'topicCache'),
          fallbackTopic: any(named: 'fallbackTopic'),
          countryCache: any(named: 'countryCache'),
          mappingCache: any(named: 'mappingCache'),
        ),
      ).thenAnswer((_) async => [headline]);

      // Arrange: Quota increment
      when(
        () => mockUsageRepo.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      ).thenAnswer(
        (_) async =>
            IngestionUsage(id: '', requestCount: 1, updatedAt: DateTime.now()),
      );

      // Arrange: Deduplication (not duplicate)
      when(
        () => mockIdempotency.isDuplicate(any(), any()),
      ).thenAnswer((_) async => false);

      // Arrange: Persistence
      when(
        () => mockHeadlineRepo.create(
          item: any(named: 'item'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async => headline);

      // Arrange: Task Finalization
      when(
        () => mockTaskRepo.update(
          id: task.id,
          item: any(named: 'item'),
        ),
      ).thenAnswer((_) async => task);

      // Act
      await service.run();

      // Assert
      verify(() => mockHeadlineRepo.create(item: headline)).called(1);
      verify(
        () => mockTaskRepo.update(
          id: task.id,
          item: any(
            named: 'item',
            that: isA<NewsAutomationTask>().having(
              (t) => t.status,
              'status',
              IngestionStatus.active,
            ),
          ),
        ),
      ).called(1);
    });

    test('handles partial batch failure gracefully', () async {
      // Arrange: 1 pending task
      when(
        () => mockTaskRepo.readAll(filter: any(named: 'filter')),
      ).thenAnswer(
        (_) async =>
            PaginatedResponse(items: [task], cursor: null, hasMore: false),
      );
      when(
        () => mockIdempotency.recordEvent(any(), scope: any(named: 'scope')),
      ).thenAnswer((_) async {});
      when(
        () => mockSourceRepo.read(id: source.id),
      ).thenAnswer((_) async => source);

      // Arrange: Provider returns 2 headlines
      final h1 = Headline(
        // Note: Using ObjectId().oid to ensure valid ID
        id: ObjectId().oid,
        title: const {SupportedLanguage.en: 'Headline 1'},
        url: 'u1',
        imageUrl: '',
        source: source,
        eventCountry: usCountry,
        topic: generalTopic,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
        isBreaking: false,
      );
      final h2 = h1.copyWith(id: ObjectId().oid, url: 'u2');

      when(
        () => mockProvider.fetchLatestHeadlines(
          any(),
          topicCache: any(named: 'topicCache'),
          fallbackTopic: any(named: 'fallbackTopic'),
          countryCache: any(named: 'countryCache'),
          mappingCache: any(named: 'mappingCache'),
        ),
      ).thenAnswer((_) async => [h1, h2]);

      when(
        () => mockUsageRepo.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      ).thenAnswer(
        (_) async =>
            IngestionUsage(id: '', requestCount: 1, updatedAt: DateTime.now()),
      );
      when(
        () => mockIdempotency.isDuplicate(any(), any()),
      ).thenAnswer((_) async => false);

      // Arrange: h1 fails to save, h2 succeeds
      when(
        () => mockHeadlineRepo.create(
          item: any(
            named: 'item',
            that: isA<Headline>().having((h) => h.url, 'url', 'u1'),
          ),
          userId: any(named: 'userId'),
        ),
      ).thenThrow(Exception('DB Error'));
      when(
        () => mockHeadlineRepo.create(
          item: any(
            named: 'item',
            that: isA<Headline>().having((h) => h.url, 'url', 'u2'),
          ),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async => h2);

      when(
        () => mockTaskRepo.update(
          id: task.id,
          item: any(named: 'item'),
        ),
      ).thenAnswer((_) async => task);

      // Act
      await service.run();

      // Assert
      verify(
        () => mockHeadlineRepo.create(
          item: any(
            named: 'item',
            that: isA<Headline>().having((h) => h.url, 'url', 'u1'),
          ),
          userId: any(named: 'userId'),
        ),
      ).called(1);
      verify(
        () => mockHeadlineRepo.create(
          item: any(
            named: 'item',
            that: isA<Headline>().having((h) => h.url, 'url', 'u2'),
          ),
          userId: any(named: 'userId'),
        ),
      ).called(1);
      // Task should still be marked successful because at least one item (h2) succeeded
      verify(
        () => mockTaskRepo.update(
          id: task.id,
          item: any(
            named: 'item',
            that: isA<NewsAutomationTask>().having(
              (t) => t.status,
              'status',
              IngestionStatus.active,
            ),
          ),
        ),
      ).called(1);
    });
  });
}
