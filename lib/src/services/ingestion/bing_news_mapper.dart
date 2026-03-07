import 'package:core/core.dart';
import 'package:verity_api/src/models/ingestion/bing_news_models.dart';
import 'package:verity_api/src/services/ingestion/aggregator_mapper.dart';
import 'package:verity_api/src/services/ingestion/topic_resolver.dart';

/// {@template bing_news_mapper}
/// Mapper for Bing News Search API responses.
/// {@endtemplate}
class BingNewsMapper extends AggregatorMapper<BingNewsArticle> {
  @override
  Headline mapToHeadline(BingNewsArticle article, Source source) {
    final now = DateTime.now();

    return Headline(
      id: '', // Assigned by repository
      title: {source.language: article.name},
      url: normalizeUrl(article.url),
      imageUrl: article.imageThumbnailUrl ?? '',
      source: source,
      eventCountry: source.headquarters,
      topic: Topic(
        id: TopicResolver.fromBing(article.category),
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
