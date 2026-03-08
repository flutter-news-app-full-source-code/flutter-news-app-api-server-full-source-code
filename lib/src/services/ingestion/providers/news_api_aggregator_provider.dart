import 'package:core/core.dart';
import 'package:verity_api/src/models/ingestion/news_api_models.dart';
import 'package:verity_api/src/services/ingestion/mappers/aggregator_mapper.dart';
import 'package:verity_api/src/services/ingestion/providers/aggregator_provider.dart' show AggregatorProvider;
import 'package:verity_api/src/services/services.dart' show AggregatorProvider;

/// {@template news_api_aggregator_provider}
/// A concrete implementation of [AggregatorProvider] for NewsAPI.org.
/// {@endtemplate}
class NewsApiAggregatorProvider implements AggregatorProvider {
  /// {@macro news_api_aggregator_provider}
  const NewsApiAggregatorProvider({
    required HttpClient httpClient,
    required AggregatorMapper<NewsApiArticle> mapper,
  }) : _httpClient = httpClient,
       _mapper = mapper;

  final HttpClient _httpClient;
  final AggregatorMapper<NewsApiArticle> _mapper;

  @override
  Future<List<Headline>> fetchLatestHeadlines(
    Source source, {
    required Map<String, Topic> topicCache,
    required Map<String, Country> countryCache,
  }) async {
    try {
      final response = await _httpClient.get<Map<String, dynamic>>(
        'everything',
        queryParameters: {
          'sources': source.url.split('/').last,
          'pageSize': '20',
          'sortBy': 'publishedAt',
        },
      );

      final dto = NewsApiResponse.fromJson(response);
      return dto.articles
          .map(
            (a) => _mapper.mapToHeadline(
              a,
              source,
              topicCache: topicCache,
              countryCache: countryCache,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }
}

