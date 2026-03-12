import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';
import 'package:verity_api/src/config/environment_config.dart';
import 'package:verity_api/src/models/ingestion/aggregator_catalog_source.dart';
import 'package:verity_api/src/models/ingestion/aggregator_source_mapping.dart';
import 'package:verity_api/src/models/ingestion/aggregator_type.dart';
import 'package:verity_api/src/models/ingestion/ingestion_topic_mapping.dart';
import 'package:verity_api/src/models/ingestion/ingestion_usage.dart';
import 'package:verity_api/src/services/idempotency_service.dart';
import 'package:verity_api/src/services/ingestion/news_ingestion_service.dart';
import 'package:verity_api/src/services/ingestion/providers/aggregator_provider.dart';

class MockTaskRepository extends Mock
    implements DataRepository<NewsAutomationTask> {}

class MockHeadlineRepository extends Mock implements DataRepository<Headline> {}

class MockSourceRepository extends Mock implements DataRepository<Source> {}

class MockTopicRepository extends Mock implements DataRepository<Topic> {}

class MockCountryRepository extends Mock implements DataRepository<Country> {}

class MockMappingRepository extends Mock
    implements DataRepository<IngestionTopicMapping> {}

class MockSourceMappingRepository extends Mock
    implements DataRepository<AggregatorSourceMapping> {}

class MockUsageRepository extends Mock
    implements DataRepository<IngestionUsage> {}

class MockAggregatorProvider extends Mock implements AggregatorProvider {}

class MockIdempotencyService extends Mock implements IdempotencyService {}

class MockLogger extends Mock implements Logger {}

class FakeHeadline extends Fake implements Headline {}

class FakeSource extends Fake implements Source {}

class FakeTopic extends Fake implements Topic {}

class FakeIngestionUsage extends Fake implements IngestionUsage {}

class FakeIngestionTopicMapping extends Fake implements IngestionTopicMapping {}

class FakeNewsAutomationTask extends Fake implements NewsAutomationTask {}

class FakeAggregatorSourceMapping extends Fake
    implements AggregatorSourceMapping {}

void main() {
  late NewsIngestionService service;
  late MockTaskRepository mockTaskRepo;
  late MockHeadlineRepository mockHeadlineRepo;
  late MockSourceRepository mockSourceRepo;
  late MockTopicRepository mockTopicRepo;
  late MockCountryRepository mockCountryRepo;
  late MockMappingRepository mockMappingRepo;
  late MockSourceMappingRepository mockSourceMappingRepo;
  late MockUsageRepository mockUsageRepo;
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
    registerFallbackValue(FakeIngestionTopicMapping());
    registerFallbackValue(FakeNewsAutomationTask());
    registerFallbackValue(FakeAggregatorSourceMapping());
    registerFallbackValue(const PaginationOptions());
    registerFallbackValue(<AggregatorSourceMapping>[]);
    registerFallbackValue(<String, Source>{});
    registerFallbackValue(<String, Topic>{});
    registerFallbackValue(<String, Country>{});
    registerFallbackValue(<String, String>{});
    registerFallbackValue(
      const PaginationOptions(limit: 300),
    );
    registerFallbackValue(
      const AggregatorCatalogSource(externalId: '', name: ''),
    );
  });

  setUp(() {
    mockTaskRepo = MockTaskRepository();
    mockHeadlineRepo = MockHeadlineRepository();
    mockSourceRepo = MockSourceRepository();
    mockTopicRepo = MockTopicRepository();
    mockCountryRepo = MockCountryRepository();
    mockMappingRepo = MockMappingRepository();
    mockSourceMappingRepo = MockSourceMappingRepository();
    mockUsageRepo = MockUsageRepository();
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
      sourceMappingRepository: mockSourceMappingRepo,
      usageRepository: mockUsageRepo,
      provider: mockProvider,
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
    when(
      () => mockSourceMappingRepo.readAll(filter: any(named: 'filter')),
    ).thenAnswer(
      (_) async =>
          const PaginatedResponse(items: [], cursor: null, hasMore: false),
    );
    when(
      () => mockSourceRepo.readAll(filter: any(named: 'filter')),
    ).thenAnswer(
      (_) async =>
          PaginatedResponse(items: [source], cursor: null, hasMore: false),
    );

    // Default quota check (not exceeded)
    when(() => mockUsageRepo.read(id: any(named: 'id'))).thenAnswer(
      (_) async => IngestionUsage(
        id: 'today',
        requestCount: 0,
        updatedAt: DateTime.now(),
      ),
    );

    // Default idempotency (success/not duplicate)
    when(
      () => mockIdempotency.recordEvent(any(), scope: any(named: 'scope')),
    ).thenAnswer((_) async {});
    when(
      () => mockIdempotency.isDuplicate(any(), any()),
    ).thenAnswer((_) async => false);
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
        mentionedCountries: [usCountry],
        topic: generalTopic,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
        isBreaking: false,
      );

      final mapping = AggregatorSourceMapping(
        id: 'm1',
        sourceId: source.id,
        aggregatorType: AggregatorType.newsApi,
        externalId: 'ext-1',
        createdAt: DateTime.now(),
      );

      when(
        () => mockSourceMappingRepo.readAll(filter: any(named: 'filter')),
      ).thenAnswer(
        (_) async =>
            PaginatedResponse(items: [mapping], cursor: null, hasMore: false),
      );

      when(
        () => mockSourceRepo.readAll(filter: any(named: 'filter')),
      ).thenAnswer(
        (_) async =>
            PaginatedResponse(items: [source], cursor: null, hasMore: false),
      );

      when(
        () => mockProvider.fetchBatchHeadlines(
          any(),
          sourceMap: any(named: 'sourceMap'),
          topicCache: any(named: 'topicCache'),
          fallbackTopic: any(named: 'fallbackTopic'),
          countryCache: any(named: 'countryCache'),
          mappingCache: any(named: 'mappingCache'),
        ),
      ).thenAnswer(
        (_) async => {
          source.id: [headline],
        },
      );

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

      // Arrange: Persistence
      when(
        () => mockHeadlineRepo.create(
          item: any(named: 'item'),
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
      verify(
        () => mockHeadlineRepo.create(
          item: any(
            named: 'item',
            that: isA<Headline>().having((h) => h.url, 'url', headline.url),
          ),
        ),
      ).called(1);
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
        () => mockSourceRepo.read(id: source.id),
      ).thenAnswer((_) async => source);

      // Arrange: Mapping exists so we proceed to batch
      final mapping = AggregatorSourceMapping(
        id: 'm1',
        sourceId: source.id,
        aggregatorType: AggregatorType.newsApi,
        externalId: 'ext-1',
        createdAt: DateTime.now(),
      );
      when(
        () => mockSourceMappingRepo.readAll(filter: any(named: 'filter')),
      ).thenAnswer(
        (_) async =>
            PaginatedResponse(items: [mapping], cursor: null, hasMore: false),
      );

      // Arrange: Provider returns 2 headlines
      final h1 = Headline(
        // Note: Using ObjectId().oid to ensure valid ID
        id: ObjectId().oid,
        title: const {SupportedLanguage.en: 'Headline 1'},
        url: 'https://example.com/u1',
        imageUrl: '',
        source: source,
        mentionedCountries: [usCountry],
        topic: generalTopic,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
        isBreaking: false,
      );
      final h2 = h1.copyWith(id: ObjectId().oid, url: 'https://example.com/u2');

      // Arrange: Ensure source is found for batch execution
      when(
        () => mockSourceRepo.readAll(filter: any(named: 'filter')),
      ).thenAnswer(
        (_) async =>
            PaginatedResponse(items: [source], cursor: null, hasMore: false),
      );

      when(
        () => mockProvider.fetchBatchHeadlines(
          any<List<AggregatorSourceMapping>>(),
          sourceMap: any<Map<String, Source>>(named: 'sourceMap'),
          topicCache: any<Map<String, Topic>>(named: 'topicCache'),
          fallbackTopic: any<Topic>(named: 'fallbackTopic'),
          countryCache: any<Map<String, Country>>(named: 'countryCache'),
          mappingCache: any<Map<String, String>>(named: 'mappingCache'),
        ),
      ).thenAnswer(
        (_) async => {
          source.id: [h1, h2],
        },
      );

      when(
        () => mockUsageRepo.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      ).thenAnswer(
        (_) async =>
            IngestionUsage(id: '', requestCount: 1, updatedAt: DateTime.now()),
      );

      // Arrange: h1 fails to save, h2 succeeds
      when(
        () => mockHeadlineRepo.create(
          item: any(
            named: 'item',
            // Use generic isA check to avoid strict matching on generated ID
            that: isA<Headline>().having(
              (h) => h.url,
              'url',
              'https://example.com/u1',
            ),
          ),
        ),
      ).thenThrow(Exception('DB Error'));
      when(
        () => mockHeadlineRepo.create(
          item: any(
            named: 'item',
            // Use generic isA check
            that: isA<Headline>().having(
              (h) => h.url,
              'url',
              'https://example.com/u2',
            ),
          ),
        ),
      ).thenAnswer((_) async => h2);

      when(
        () => mockTaskRepo.update(
          id: task.id,
          item: any(named: 'item'),
        ),
      ).thenAnswer((_) async => task);

      await service.run();

      verify(
        () => mockHeadlineRepo.create(
          item: any(
            named: 'item',
            that: isA<Headline>().having(
              (h) => h.url,
              'url',
              'https://example.com/u1',
            ),
          ),
        ),
      ).called(1);
      verify(
        () => mockHeadlineRepo.create(
          item: any(
            named: 'item',
            that: isA<Headline>().having(
              (h) => h.url,
              'url',
              'https://example.com/u2',
            ),
          ),
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

    test(
      'Phase 1: Discovery - Triggers catalog sync when mapping missing',
      () async {
        // Arrange: Task claimed but mapping missing in DB
        when(
          () => mockTaskRepo.readAll(filter: any(named: 'filter')),
        ).thenAnswer(
          (_) async =>
              PaginatedResponse(items: [task], cursor: null, hasMore: false),
        );
        when(
          () => mockSourceMappingRepo.readAll(filter: any(named: 'filter')),
        ).thenAnswer(
          (_) async => const PaginatedResponse(
            items: [],
            cursor: null,
            hasMore: false,
          ),
        );

        // Arrange: Provider returns catalog
        final catalogSource = AggregatorCatalogSource(
          externalId: 'ext-1',
          name: 'Example',
          url: source.url,
        );
        when(
          () => mockProvider.syncCatalog(),
        ).thenAnswer((_) async => [catalogSource]);

        // Arrange: Repository mocks for mapping creation
        when(
          () => mockSourceRepo.read(id: source.id),
        ).thenAnswer((_) async => source);
        when(
          () => mockSourceMappingRepo.create(item: any(named: 'item')),
        ).thenAnswer((_) async => FakeAggregatorSourceMapping());

        // Arrange: Batch fetch success
        when(
          () => mockSourceRepo.readAll(filter: any(named: 'filter')),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [source],
            cursor: null,
            hasMore: false,
          ),
        );
        when(
          () => mockProvider.fetchBatchHeadlines(
            any<List<AggregatorSourceMapping>>(),
            sourceMap: any<Map<String, Source>>(named: 'sourceMap'),
            topicCache: any<Map<String, Topic>>(named: 'topicCache'),
            fallbackTopic: any<Topic>(named: 'fallbackTopic'),
            countryCache: any<Map<String, Country>>(named: 'countryCache'),
            mappingCache: any<Map<String, String>>(named: 'mappingCache'),
          ),
        ).thenAnswer((_) async => {});

        await service.run();

        verify(() => mockProvider.syncCatalog()).called(1);
        verify(
          () => mockSourceMappingRepo.create(item: any(named: 'item')),
        ).called(1);
      },
    );

    test(
      'Phase 2: Poison Pill Isolation - Disables mapping on 400 error',
      () async {
        final mapping = AggregatorSourceMapping(
          id: 'm1',
          sourceId: source.id,
          aggregatorType: AggregatorType.newsApi,
          externalId: 'bad-source',
          createdAt: DateTime.now(),
        );

        // Arrange: Task and Mapping exist
        when(
          () => mockTaskRepo.readAll(filter: any(named: 'filter')),
        ).thenAnswer(
          (_) async =>
              PaginatedResponse(items: [task], cursor: null, hasMore: false),
        );
        when(
          () => mockSourceMappingRepo.readAll(filter: any(named: 'filter')),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [mapping],
            cursor: null,
            hasMore: false,
          ),
        );
        when(
          () => mockSourceRepo.readAll(filter: any(named: 'filter')),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [source],
            cursor: null,
            hasMore: false,
          ),
        );

        // Arrange: Batch fetch fails with BadRequest (Poison Pill detected)
        when(
          () => mockProvider.fetchBatchHeadlines(
            any<List<AggregatorSourceMapping>>(),
            sourceMap: any<Map<String, Source>>(named: 'sourceMap'),
            topicCache: any<Map<String, Topic>>(named: 'topicCache'),
            fallbackTopic: any<Topic>(named: 'fallbackTopic'),
            countryCache: any<Map<String, Country>>(named: 'countryCache'),
            mappingCache: any<Map<String, String>>(named: 'mappingCache'),
          ),
        ).thenThrow(const BadRequestException('Invalid Source'));

        // Arrange: Mapping update mock
        when(
          () => mockSourceMappingRepo.update(
            id: any(named: 'id'),
            item: any(named: 'item'),
          ),
        ).thenAnswer((_) async => mapping);

        // Arrange: Task finalization mock
        when(
          () => mockTaskRepo.update(
            id: any(named: 'id'),
            item: any(named: 'item'),
          ),
        ).thenAnswer((_) async => task);

        await service.run();

        // Assert: The mapping was disabled
        verify(
          () => mockSourceMappingRepo.update(
            id: 'm1',
            item: any(
              named: 'item',
              that: isA<AggregatorSourceMapping>().having(
                (m) => m.isEnabled,
                'isEnabled',
                false,
              ),
            ),
          ),
        ).called(1);

        // Assert: The task was marked as error
        verify(
          () => mockTaskRepo.update(
            id: task.id,
            item: any(
              named: 'item',
              that: isA<NewsAutomationTask>().having(
                (t) => t.status,
                'status',
                IngestionStatus.error,
              ),
            ),
          ),
        ).called(1);
      },
    );
  });
}
