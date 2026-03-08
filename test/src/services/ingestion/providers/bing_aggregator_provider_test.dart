import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:verity_api/src/models/ingestion/bing_news_models.dart';
import 'package:verity_api/src/services/ingestion/mappers/bing_news_mapper.dart';
import 'package:verity_api/src/services/ingestion/providers/bing_aggregator_provider.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockBingNewsMapper extends Mock implements BingNewsMapper {}

class MockLogger extends Mock implements Logger {}

class FakeBingNewsArticle extends Fake implements BingNewsArticle {}

void main() {
  late BingNewsAggregatorProvider provider;
  late MockHttpClient mockHttpClient;
  late MockBingNewsMapper mockMapper;
  late MockLogger mockLogger;

  late Source source;
  late Topic fallbackTopic;
  late Map<String, Topic> topicCache;
  late Map<String, Country> countryCache;
  late Map<String, String> mappingCache;

  setUpAll(() {
    registerFallbackValue(FakeBingNewsArticle());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockMapper = MockBingNewsMapper();
    mockLogger = MockLogger();

    provider = BingNewsAggregatorProvider(
      httpClient: mockHttpClient,
      mapper: mockMapper,
      log: mockLogger,
    );

    source = Source(
      id: 'source-id',
      name: const {SupportedLanguage.en: 'CNN'},
      description: const {},
      url: 'https://www.cnn.com',
      sourceType: SourceType.newsAgency,
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
        'value': [
          {
            'name': 'Test Article',
            'url': 'https://cnn.com/article',
            'description': 'Desc',
            'datePublished': '2023-01-01T00:00:00.000Z',
          },
        ],
      };

      when(
        () => mockHttpClient.get<Map<String, dynamic>>(
          'search',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => apiResponse);

      final expectedHeadline = Headline(
        id: '',
        title: const {},
        url: 'https://cnn.com/article',
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
          'search',
          queryParameters: const BingNewsRequest(
            query: 'site:www.cnn.com',
          ).toJson(),
        ),
      ).called(1);
    },
  );

  test('fetchLatestHeadlines handles partial mapping failures', () async {
    final apiResponse = {
      'value': [
        {
          'name': 'Valid Article',
          'url': 'https://cnn.com/1',
          'description': 'Description 1',
          'datePublished': '2023-01-01T00:00:00.000Z',
        },
        {
          'name': 'Invalid Article',
          'url': 'https://cnn.com/2',
          'description': 'Description 2',
          'datePublished': '2023-01-01T00:00:00.000Z',
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
      url: 'https://cnn.com/1',
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
      final article = invocation.positionalArguments[0] as BingNewsArticle;
      if (article.name == 'Valid Article') return validHeadline;
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
        any(that: contains('Failed to map Bing article')),
        any(),
        any(),
      ),
    ).called(1);
  });
}
