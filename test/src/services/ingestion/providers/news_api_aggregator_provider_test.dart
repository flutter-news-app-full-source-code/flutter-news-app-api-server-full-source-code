import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:verity_api/src/models/ingestion/aggregator_source_mapping.dart';
import 'package:verity_api/src/models/ingestion/aggregator_type.dart';
import 'package:verity_api/src/models/ingestion/news_api_models.dart';
import 'package:verity_api/src/services/ingestion/mappers/news_api_mapper.dart';
import 'package:verity_api/src/services/ingestion/providers/news_api_aggregator_provider.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockNewsApiMapper extends Mock implements NewsApiMapper {}

class MockLogger extends Mock implements Logger {}

class FakeNewsApiArticle extends Fake implements NewsApiArticle {}

class FakeAggregatorSourceMapping extends Fake
    implements AggregatorSourceMapping {}

void main() {
  late NewsApiAggregatorProvider provider;
  late MockHttpClient mockHttpClient;
  late MockNewsApiMapper mockMapper;
  late MockLogger mockLogger;

  late Source source;
  late Topic fallbackTopic;
  late Map<String, Topic> topicCache;
  late Map<String, Country> countryCache;
  late Map<String, String> mappingCache;
  late AggregatorSourceMapping mapping;

  setUpAll(() {
    registerFallbackValue(FakeNewsApiArticle());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockMapper = MockNewsApiMapper();
    mockLogger = MockLogger();

    provider = NewsApiAggregatorProvider(
      httpClient: mockHttpClient,
      mapper: mockMapper,
      log: mockLogger,
    );

    source = Source(
      id: 'source-id',
      name: const {SupportedLanguage.en: 'TechCrunch'},
      description: const {},
      url:
          'https://techcrunch.com/techcrunch', // ID extracted from last segment
      sourceType: SourceType.specializedPublisher,
      language: SupportedLanguage.en,
      headquarters: const Country(
        id: 'us',
        isoCode: 'US',
        name: {},
        flagUrl: '',
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
    );

    fallbackTopic = Topic(
      id: 'fallback',
      name: const {},
      description: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
    );
    topicCache = {};
    countryCache = {};
    mappingCache = {};

    mapping = AggregatorSourceMapping(
      id: 'm1',
      sourceId: source.id,
      aggregatorType: AggregatorType.newsApi,
      externalId: 'techcrunch',
      createdAt: DateTime.now(),
    );
  });

  test(
    'fetchBatchHeadlines calls correct endpoint and attributes results',
    () async {
      final apiResponse = {
        'status': 'ok',
        'totalResults': 1,
        'articles': [
          {
            'source': {'id': 'techcrunch', 'name': 'TechCrunch'},
            'title': 'Test Article',
            'url': 'https://techcrunch.com/article',
            'publishedAt': '2023-01-01T00:00:00.000Z',
            'description': 'Desc',
          },
        ],
      };

      when(
        () => mockHttpClient.get<Map<String, dynamic>>(
          'everything',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => apiResponse);

      final expectedHeadline = Headline(
        id: '',
        title: const {},
        url: 'https://techcrunch.com/article',
        imageUrl: '',
        source: source,
        eventCountry: source.headquarters,
        topic: fallbackTopic,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
        isBreaking: false,
      );

      when(
        () => mockMapper.mapToHeadline(
          any(),
          source,
          topicCache: topicCache,
          fallbackTopic: fallbackTopic,
          countryCache: countryCache,
          mappingCache: mappingCache,
        ),
      ).thenReturn(expectedHeadline);

      final result = await provider.fetchBatchHeadlines(
        [mapping],
        sourceMap: {source.id: source},
        topicCache: topicCache,
        fallbackTopic: fallbackTopic,
        countryCache: countryCache,
        mappingCache: mappingCache,
      );

      expect(result[source.id], hasLength(1));
      expect(result[source.id]!.first, expectedHeadline);

      verify(
        () => mockHttpClient.get<Map<String, dynamic>>(
          'everything',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).called(1);
    },
  );

  test('syncCatalog calls sources endpoint and returns catalog DTOs', () async {
    final apiResponse = {
      'status': 'ok',
      'sources': [
        {
          'id': 'abc-news',
          'name': 'ABC News',
          'url': 'https://abcnews.go.com',
        },
      ],
    };

    when(
      () => mockHttpClient.get<Map<String, dynamic>>(
        'top-headlines/sources',
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => apiResponse);

    final result = await provider.syncCatalog();

    expect(result, hasLength(1));
    expect(result.first.externalId, 'abc-news');
    expect(result.first.url, 'https://abcnews.go.com');
  });

  test('fetchBatchHeadlines chunks requests when sources exceed 10', () async {
    final manyMappings = List.generate(
      15,
      (i) => AggregatorSourceMapping(
        id: 'm$i',
        sourceId: 's$i',
        aggregatorType: AggregatorType.newsApi,
        externalId: 'ext-$i',
        createdAt: DateTime.now(),
      ),
    );

    final sourceMap = {for (var m in manyMappings) m.sourceId: source};

    when(
      () => mockHttpClient.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => {
        'status': 'ok',
        'totalResults': 0,
        'articles': [],
      },
    );

    await provider.fetchBatchHeadlines(
      manyMappings,
      sourceMap: sourceMap,
      topicCache: {},
      fallbackTopic: fallbackTopic,
      countryCache: {},
      mappingCache: {},
    );

    // 15 sources / 10 batch size = 2 calls
    verify(
      () => mockHttpClient.get<Map<String, dynamic>>(
        'everything',
        queryParameters: any(
          named: 'queryParameters',
          that: isA<Map<String, dynamic>>().having(
            (p) => (p['sources'] as String).split(',').length,
            'source count in chunk',
            lessThanOrEqualTo(10),
          ),
        ),
      ),
    ).called(2);
  });
}
