import 'package:core/core.dart';
import 'package:test/test.dart';
import 'package:verity_api/src/models/ingestion/bing_news_models.dart';
import 'package:verity_api/src/services/ingestion/mappers/bing_news_mapper.dart';

void main() {
  late BingNewsMapper mapper;
  late Source source;
  late Topic fallbackTopic;
  late Topic businessTopic;
  late Country usCountry;
  late Map<String, Topic> topicCache;
  late Map<String, Country> countryCache;
  late Map<String, String> mappingCache;

  setUp(() {
    mapper = BingNewsMapper();

    usCountry = const Country(
      id: 'us-id',
      isoCode: 'US',
      name: {SupportedLanguage.en: 'United States'},
      flagUrl: 'us.png',
    );

    source = Source(
      id: 'source-id',
      name: const {SupportedLanguage.en: 'Test Source'},
      description: const {},
      url: 'https://testsource.com',
      sourceType: SourceType.newsAgency,
      language: SupportedLanguage.en,
      headquarters: usCountry,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
    );

    fallbackTopic = Topic(
      id: 'fallback-id',
      name: const {SupportedLanguage.en: 'General'},
      description: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
    );

    businessTopic = Topic(
      id: 'business-id',
      name: const {SupportedLanguage.en: 'Business'},
      description: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
    );

    topicCache = {
      'fallback-id': fallbackTopic,
      'business-id': businessTopic,
    };

    countryCache = {'us': usCountry};

    mappingCache = {'business': 'business-id'};
  });

  test('mapToHeadline maps fields correctly', () {
    final article = BingNewsArticle(
      name: 'Test Headline',
      url: 'https://example.com/article',
      description: 'Test Description',
      datePublished: DateTime.now(),
      category: 'Business',
      imageThumbnailUrl: 'https://example.com/img.jpg',
    );

    final headline = mapper.mapToHeadline(
      article,
      source,
      topicCache: topicCache,
      fallbackTopic: fallbackTopic,
      countryCache: countryCache,
      mappingCache: mappingCache,
    );

    expect(headline.title[SupportedLanguage.en], 'Test Headline');
    expect(headline.url, 'https://example.com/article');
    expect(headline.imageUrl, 'https://example.com/img.jpg');
    expect(headline.source, source);
    expect(headline.eventCountry, source.headquarters);
    // Verify topic resolution via mapping
    expect(headline.topic, businessTopic);
  });

  test('mapToHeadline uses fallback topic when mapping missing', () {
    final article = BingNewsArticle(
      name: 'Test',
      url: 'https://example.com',
      description: 'Desc',
      datePublished: DateTime.now(),
      category: 'UnknownCategory',
    );

    final headline = mapper.mapToHeadline(
      article,
      source,
      topicCache: topicCache,
      fallbackTopic: fallbackTopic,
      countryCache: countryCache,
      mappingCache: mappingCache,
    );

    expect(headline.topic, fallbackTopic);
  });
}
