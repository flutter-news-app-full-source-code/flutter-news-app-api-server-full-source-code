import 'package:core/core.dart';
import 'package:verity_api/src/models/ingestion/news_api_models.dart';
import 'package:verity_api/src/services/ingestion/aggregator_mapper.dart';
import 'package:verity_api/src/services/ingestion/topic_resolver.dart';

/// {@template news_api_mapper}
/// Mapper for NewsAPI.org responses.
/// {@endtemplate}
class NewsApiMapper extends AggregatorMapper<NewsApiArticle> {
  @override
  Headline mapToHeadline(NewsApiArticle article, Source source) {
    final now = DateTime.now();

    return Headline(
      id: '', // Assigned by repository
      title: {source.language: article.title},
      url: normalizeUrl(article.url),
      imageUrl: article.urlToImage ?? '',
      source: source,
      eventCountry: source.headquarters,
      topic: Topic(
        id: TopicResolver.fromNewsApi(null),
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
