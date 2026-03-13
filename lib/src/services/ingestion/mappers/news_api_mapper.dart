// ignore_for_file: public_member_api_docs

import 'package:core/core.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:verity_api/src/models/ingestion/news_api_models.dart';
import 'package:verity_api/src/services/ingestion/mappers/aggregator_mapper.dart';

/// {@template news_api_mapper}
/// Mapper for NewsAPI.org responses.
/// {@endtemplate}
class NewsApiMapper extends AggregatorMapper<NewsApiArticle> {
  /// Enumerated External Vocabulary for NewsAPI.org
  static const categoryBusiness = 'business';
  static const categoryTechnology = 'technology';
  static const categoryScience = 'science';
  static const categoryHealth = 'health';
  static const categorySports = 'sports';
  static const categoryEntertainment = 'entertainment';
  static const categoryGeneral = 'general';

  @override
  Headline mapToHeadline(
    NewsApiArticle article,
    Source source, {
    required Map<String, Topic> topicCache,
    required Topic fallbackTopic,
    required Map<String, Country> countryCache,
    required Map<String, String> mappingCache,
  }) {
    final now = DateTime.now();

    return Headline(
      id: ObjectId().oid,
      title: {source.language: article.title},
      url: normalizeUrl(article.url),
      imageUrl: article.urlToImage ?? '',
      source: source,
      topic: resolveTopic(null, topicCache, fallbackTopic, mappingCache),
      createdAt: now,
      updatedAt: now,
      // All ingested content starts as draft until processed by Intelligence Worker.
      status: ContentStatus.draft,
      isBreaking: false,
      lastEnrichedAt: null,
      mentionedCountries: [source.headquarters],
      mentionedPersons: const [],
    );
  }
}
