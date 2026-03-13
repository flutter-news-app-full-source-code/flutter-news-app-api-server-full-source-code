import 'package:core/core.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:veritai_api/src/models/ingestion/media_stack_models.dart';
import 'package:veritai_api/src/services/ingestion/mappers/aggregator_mapper.dart';

/// {@template media_stack_mapper}
/// Mapper for MediaStack API responses.
/// {@endtemplate}
class MediaStackMapper extends AggregatorMapper<MediaStackArticle> {
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
      // MediaStack provides a category string (e.g., 'business').
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
      mentionedCountries: const [],
      mentionedPersons: const [],
    );
  }
}
