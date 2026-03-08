import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:verity_api/src/models/ingestion/mediastack_models.dart';
import 'package:verity_api/src/services/ingestion/mappers/mediastack_mapper.dart';
import 'package:verity_api/src/services/ingestion/providers/mediastack_aggregator_provider.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockMediaStackMapper extends Mock implements MediaStackMapper {}

class MockLogger extends Mock implements Logger {}

class FakeMediaStackArticle extends Fake implements MediaStackArticle {}

void main() {
  late MediaStackAggregatorProvider provider;
  late MockHttpClient mockHttpClient;
  late MockMediaStackMapper mockMapper;
  late MockLogger mockLogger;

  late Source source;
  late Topic fallbackTopic;
  late Map<String, Topic> topicCache;
  late Map<String, Country> countryCache;
  late Map<String, String> mappingCache;

  setUpAll(() {
    registerFallbackValue(FakeMediaStackArticle());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockMapper = MockMediaStackMapper();
    mockLogger = MockLogger();

    provider = MediaStackAggregatorProvider(
      httpClient: mockHttpClient,
      mapper: mockMapper,
      log: mockLogger,
    );

    source = Source(
      id: 'source-id',
      name: const {SupportedLanguage.en: 'BBC'},
      description: const {},
      url: 'https://bbc.com/news/bbc', // ID extracted from last segment
      sourceType: SourceType.newsAgency,
      language: SupportedLanguage.en,
      headquarters: const Country(
        id: 'uk',
        isoCode: 'GB',
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
        'data': [
          {
            'title': 'Test Article',
            'url': 'https://bbc.com/article',
            'description': 'Desc',
            'published_at': '2023-01-01T00:00:00.000Z',
            'category': 'general',
            'language': 'en',
            'country': 'gb',
          },
        ],
      };

      when(
        () => mockHttpClient.get<Map<String, dynamic>>(
          'news',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => apiResponse);

      final expectedHeadline = Headline(
        id: '',
        title: const {},
        url: 'https://bbc.com/article',
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
          'news',
          queryParameters: {'sources': 'bbc', 'limit': '20', 'languages': 'en'},
        ),
      ).called(1);
    },
  );
}
