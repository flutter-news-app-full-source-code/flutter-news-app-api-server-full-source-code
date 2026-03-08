// ignore_for_file: public_member_api_docs

import 'package:core/core.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:verity_api/src/models/ingestion/mediastack_models.dart';
import 'package:verity_api/src/services/ingestion/mappers/aggregator_mapper.dart';

/// {@template mediastack_mapper}
/// Mapper for MediaStack API responses.
/// {@endtemplate}
class MediaStackMapper extends AggregatorMapper<MediaStackArticle> {
  /// Enumerated External Vocabulary for MediaStack
  static const categoryBusiness = 'business';
  static const categoryEntertainment = 'entertainment';
  static const categoryGeneral = 'general';
  static const categoryHealth = 'health';
  static const categoryScience = 'science';
  static const categorySports = 'sports';
  static const categoryTechnology = 'technology';

  @override
  Headline mapToHeadline(
    MediaStackArticle article,
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
      imageUrl: article.image ?? '',
      source: source,
      eventCountry: resolveCountry(
        article.country,
        countryCache,
        source.headquarters,
      ),
      topic: resolveTopic(
        article.category,
        topicCache,
        fallbackTopic,
        mappingCache,
      ),
      createdAt: now,
      updatedAt: now,
      status: ContentStatus.active,
      isBreaking: false,
    );
  }
}
