import 'package:core/core.dart';
import 'package:test/test.dart';
import 'package:verity_api/src/models/ingestion/mediastack_models.dart';
import 'package:verity_api/src/services/ingestion/mappers/mediastack_mapper.dart';

void main() {
  late MediaStackMapper mapper;
  late Source source;
  late Topic fallbackTopic;
  late Topic techTopic;
  late Country usCountry;
  late Map<String, Topic> topicCache;
  late Map<String, Country> countryCache;
  late Map<String, String> mappingCache;

  setUp(() {
    mapper = MediaStackMapper();

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

    techTopic = Topic(
      id: 'tech-id',
      name: const {SupportedLanguage.en: 'Technology'},
      description: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
    );

    topicCache = {
      'fallback-id': fallbackTopic,
      'tech-id': techTopic,
    };

    countryCache = {'us': usCountry};

    mappingCache = {'technology': 'tech-id'};
  });

  test('mapToHeadline maps fields correctly', () {
    final article = MediaStackArticle(
      title: 'Tech News',
      url: 'https://example.com/tech',
      description: 'Tech Desc',
      image: 'https://example.com/tech.jpg',
      publishedAt: DateTime.now(),
      category: 'technology',
      language: 'en',
      country: 'us',
    );

    final headline = mapper.mapToHeadline(
      article,
      source,
      topicCache: topicCache,
      fallbackTopic: fallbackTopic,
      countryCache: countryCache,
      mappingCache: mappingCache,
    );

    expect(headline.title[SupportedLanguage.en], 'Tech News');
    expect(headline.url, 'https://example.com/tech');
    expect(headline.imageUrl, 'https://example.com/tech.jpg');
    expect(headline.topic, techTopic);
    // Verify country resolution from article data
    expect(headline.eventCountry, usCountry);
  });

  test(
    'mapToHeadline falls back to source headquarters if country unknown',
    () {
      final article = MediaStackArticle(
        title: 'News',
        url: 'https://example.com',
        description: 'Desc',
        image: null,
        publishedAt: DateTime.now(),
        category: 'general',
        language: 'en',
        country: 'xx', // Unknown country code
      );

      final headline = mapper.mapToHeadline(
        article,
        source,
        topicCache: topicCache,
        fallbackTopic: fallbackTopic,
        countryCache: countryCache,
        mappingCache: mappingCache,
      );

      expect(headline.eventCountry, source.headquarters);
    },
  );
}
