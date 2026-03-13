import 'package:core/core.dart';
import 'package:test/test.dart';
import 'package:verity_api/src/models/ingestion/news_api_models.dart';
import 'package:verity_api/src/services/ingestion/mappers/news_api_mapper.dart';

void main() {
  late NewsApiMapper mapper;
  late Source source;
  late Topic fallbackTopic;
  late Country usCountry;
  late Map<String, Topic> topicCache;
  late Map<String, Country> countryCache;
  late Map<String, String> mappingCache;

  setUp(() {
    mapper = NewsApiMapper();

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

    topicCache = {
      'fallback-id': fallbackTopic,
    };

    countryCache = {'us': usCountry};
    mappingCache = {};
  });

  test('mapToHeadline maps fields correctly', () {
    final article = NewsApiArticle(
      source: const NewsApiSource(name: 'Test', id: 'test'),
      title: 'Breaking News',
      url: 'https://example.com/breaking',
      publishedAt: DateTime.now(),
      description: 'Breaking Desc',
      urlToImage: 'https://example.com/breaking.jpg',
    );

    final headline = mapper.mapToHeadline(
      article,
      source,
      topicCache: topicCache,
      fallbackTopic: fallbackTopic,
      countryCache: countryCache,
      mappingCache: mappingCache,
    );

    expect(headline.title[SupportedLanguage.en], 'Breaking News');
    expect(headline.url, 'https://example.com/breaking');
    expect(headline.imageUrl, 'https://example.com/breaking.jpg');
    expect(headline.source, source);
    expect(headline.mentionedCountries.first, source.headquarters);
    // NewsAPI doesn't provide categories per article, so it should always
    // resolve to the fallback topic (or whatever logic is in resolveTopic).
    expect(headline.topic, fallbackTopic);
    expect(headline.status, ContentStatus.draft);
  });

  test('mapToHeadline uses source language for title key', () {
    final frenchSource = source.copyWith(language: SupportedLanguage.fr);
    final article = NewsApiArticle(
      source: const NewsApiSource(name: 'Test', id: 'test'),
      title: 'Nouvelles de dernière heure',
      url: 'https://example.com/breaking',
      publishedAt: DateTime.now(),
    );

    final headline = mapper.mapToHeadline(
      article,
      frenchSource,
      topicCache: topicCache,
      fallbackTopic: fallbackTopic,
      countryCache: countryCache,
      mappingCache: mappingCache,
    );

    expect(headline.title[SupportedLanguage.fr], 'Nouvelles de dernière heure');
    expect(headline.title.containsKey(SupportedLanguage.en), isFalse);
  });

  test('resolveTopic uses mappingCache if available', () {
    final techTopic = Topic(
      id: 'topic-tech',
      name: const {SupportedLanguage.en: 'Technology'},
      description: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
    );
    topicCache['topic-tech'] = techTopic;
    mappingCache['technology'] = 'topic-tech';

    final resolved = mapper.resolveTopic(
      'technology',
      topicCache,
      fallbackTopic,
      mappingCache,
    );
    expect(resolved, techTopic);
  });
}
