import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:verity_api/src/models/ingestion/news_api_models.dart';
import 'package:verity_api/src/services/ingestion/mappers/news_api_mapper.dart';
import 'package:verity_api/src/services/ingestion/providers/news_api_aggregator_provider.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockNewsApiMapper extends Mock implements NewsApiMapper {}

class MockLogger extends Mock implements Logger {}

class FakeNewsApiArticle extends Fake implements NewsApiArticle {}

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
  });

  test(
    'fetchLatestHeadlines calls correct endpoint and returns headlines',
    () async {
      final apiResponse = {
        'status': 'ok',
        'totalResults': 1,
        'articles': [
          {
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

      final result = await provider.fetchLatestHeadlines(
        source,
        topicCache: topicCache,
        fallbackTopic: fallbackTopic,
        countryCache: countryCache,
        mappingCache: mappingCache,
      );

      expect(result, hasLength(1));
      expect(result.first, expectedHeadline);

      verify(
        () => mockHttpClient.get<Map<String, dynamic>>(
          'everything',
          queryParameters: const NewsApiRequest(
            domains: 'techcrunch.com',
          ).toJson(),
        ),
      ).called(1);
    },
  );

  test('fetchLatestHeadlines handles partial mapping failures', () async {
    final apiResponse = {
      'status': 'ok',
      'totalResults': 2,
      'articles': [
        {
          'title': 'Valid Article',
          'url': 'https://techcrunch.com/1',
          'publishedAt': '2023-01-01T00:00:00.000Z',
        },
        {
          'title': 'Invalid Article',
          'url': 'https://techcrunch.com/2',
          'publishedAt': '2023-01-01T00:00:00.000Z',
        },
      ],
    };

    when(
      () => mockHttpClient.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => apiResponse);

    final validHeadline = Headline(
      id: '1',
      title: const {},
      url: 'https://techcrunch.com/1',
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
    ).thenAnswer((invocation) {
      final article = invocation.positionalArguments[0] as NewsApiArticle;
      if (article.title == 'Valid Article') return validHeadline;
      throw Exception('Mapping failed');
    });

    final result = await provider.fetchLatestHeadlines(
      source,
      topicCache: topicCache,
      fallbackTopic: fallbackTopic,
      countryCache: countryCache,
      mappingCache: mappingCache,
    );

    expect(result, hasLength(1));
    expect(result.first, validHeadline);

    verify(
      () => mockLogger.warning(
        any(that: contains('Failed to map NewsAPI article')),
        any(),
        any(),
      ),
    ).called(1);
  });
}
