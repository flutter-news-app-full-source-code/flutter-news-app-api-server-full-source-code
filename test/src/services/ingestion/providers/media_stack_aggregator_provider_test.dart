import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:verity_api/src/models/ingestion/aggregator_source_mapping.dart';
import 'package:verity_api/src/models/ingestion/aggregator_type.dart';
import 'package:verity_api/src/models/ingestion/media_stack_models.dart';
import 'package:verity_api/src/services/ingestion/mappers/aggregator_mapper.dart';
import 'package:verity_api/src/services/ingestion/providers/media_stack_aggregator_provider.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockMediaStackMapper extends Mock
    implements AggregatorMapper<MediaStackArticle> {}

class MockLogger extends Mock implements Logger {}

class FakeMediaStackArticle extends Fake implements MediaStackArticle {}

class FakeTopic extends Fake implements Topic {}

void main() {
  late MediaStackAggregatorProvider provider;
  late MockHttpClient mockHttpClient;
  late MockMediaStackMapper mockMapper;
  late MockLogger mockLogger;

  late Source source;
  late Topic fallbackTopic;
  late AggregatorSourceMapping mapping;

  setUpAll(() {
    registerFallbackValue(FakeMediaStackArticle());
    registerFallbackValue(FakeTopic());
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
      id: 's1',
      name: const {SupportedLanguage.en: 'BBC'},
      description: const {},
      url: 'https://bbc.com',
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
      id: 'f1',
      name: const {},
      description: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
    );

    mapping = AggregatorSourceMapping(
      id: 'm1',
      sourceId: source.id,
      aggregatorType: AggregatorType.mediaStack,
      externalId: 'BBC News',
      createdAt: DateTime.now(),
    );
  });

  test('syncCatalog returns catalog DTOs from sources endpoint', () async {
    final apiResponse = {
      'data': [
        {
          'name': 'BBC News',
          'url': 'https://bbc.com',
          'category': 'general',
          'language': 'en',
          'country': 'gb',
        },
      ],
    };

    when(
      () => mockHttpClient.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => apiResponse);

    final result = await provider.syncCatalog();

    expect(result, hasLength(1));
    expect(result.first.externalId, 'BBC News');
    verify(
      () => mockHttpClient.get<Map<String, dynamic>>(
        'sources',
        queryParameters: {},
      ),
    ).called(1);
  });

  test('fetchBatchHeadlines attributes articles by source name', () async {
    final apiResponse = {
      'pagination': {'limit': 100, 'offset': 0, 'count': 1, 'total': 1},
      'data': [
        {
          'title': 'Test',
          'url': 'https://bbc.com/1',
          'source': 'BBC News',
          'category': 'general',
          'language': 'en',
          'country': 'gb',
          'published_at': '2023-01-01T00:00:00Z',
        },
      ],
    };

    when(
      () => mockHttpClient.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => apiResponse);

    final headline = Headline(
      id: 'h1',
      title: const {},
      url: 'https://bbc.com/1',
      imageUrl: '',
      source: source,
      mentionedCountries: [source.headquarters],
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
        topicCache: any(named: 'topicCache'),
        fallbackTopic: any(named: 'fallbackTopic'),
        countryCache: any(named: 'countryCache'),
        mappingCache: any(named: 'mappingCache'),
      ),
    ).thenReturn(headline);

    final result = await provider.fetchBatchHeadlines(
      [mapping],
      sourceMap: {source.id: source},
      topicCache: {},
      fallbackTopic: fallbackTopic,
      countryCache: {},
      mappingCache: {},
    );

    expect(result[source.id], hasLength(1));
    expect(result[source.id]!.first, headline);
  });
}
