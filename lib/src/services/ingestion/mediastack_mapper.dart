import 'package:core/core.dart';
import 'package:verity_api/src/models/ingestion/mediastack_models.dart';
import 'package:verity_api/src/services/ingestion/aggregator_mapper.dart';
import 'package:verity_api/src/services/ingestion/topic_resolver.dart';

/// {@template mediastack_mapper}
/// Mapper for MediaStack API responses.
/// {@endtemplate}
class MediaStackMapper extends AggregatorMapper<MediaStackArticle> {
  @override
  Headline mapToHeadline(MediaStackArticle article, Source source) {
    final now = DateTime.now();

    return Headline(
      id: '', // Assigned by repository
      title: {source.language: article.title},
      url: normalizeUrl(article.url),
      imageUrl: article.image ?? '',
      source: source,
      eventCountry: source.headquarters,
      // Topic is a placeholder; hydrated by ContentEnrichmentService
      topic: Topic(
        id: TopicResolver.fromMediaStack(article.category),
        name: const {},
        description: const {},
        createdAt: now,
        updatedAt: now,
        status: ContentStatus.active,
      ),
      createdAt: now,
      updatedAt: now,
      status: ContentStatus.active,
      isBreaking: false,
    );
  }
}
