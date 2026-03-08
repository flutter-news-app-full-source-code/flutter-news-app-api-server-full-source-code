// ignore_for_file: public_member_api_docs

import 'package:core/core.dart';
import 'package:verity_api/src/models/ingestion/bing_news_models.dart';
import 'package:verity_api/src/services/ingestion/mappers/aggregator_mapper.dart';

/// {@template bing_news_mapper}
/// Mapper for Bing News Search API responses.
/// {@endtemplate}
class BingNewsMapper extends AggregatorMapper<BingNewsArticle> {
  /// Enumerated External Vocabulary for Bing News
  static const categoryBusiness = 'Business';
  static const categoryEntertainment = 'Entertainment';
  static const categoryHealth = 'Health';
  static const categoryPolitics = 'Politics';
  static const categoryScienceAndTechnology = 'ScienceAndTechnology';
  static const categorySports = 'Sports';
  static const categoryWorld = 'World';
  static const categoryUS = 'US';

  @override
  Headline mapToHeadline(
    BingNewsArticle article,
    Source source, {
    required Map<String, Topic> topicCache,
    required Map<String, Country> countryCache,
    required Map<String, String> mappingCache,
  }) {
    final now = DateTime.now();

    return Headline(
      id: '', // Assigned by repository
      title: {source.language: article.name},
      url: normalizeUrl(article.url),
      imageUrl: article.imageThumbnailUrl ?? '',
      source: source,
      eventCountry: source.headquarters,
      topic: resolveTopic(article.category, topicCache, mappingCache),
      createdAt: now,
      updatedAt: now,
      status: ContentStatus.active,
      isBreaking: false,
    );
  }
}
