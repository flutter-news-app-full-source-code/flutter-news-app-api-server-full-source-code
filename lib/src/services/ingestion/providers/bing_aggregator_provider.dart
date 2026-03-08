import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:verity_api/src/models/ingestion/bing_news_models.dart';
import 'package:verity_api/src/services/ingestion/ingestion.dart';

/// {@template bing_aggregator_provider}
/// A concrete implementation of [AggregatorProvider] for Bing News.
/// {@endtemplate}
class BingNewsAggregatorProvider implements AggregatorProvider {
  /// {@macro bing_aggregator_provider}
  const BingNewsAggregatorProvider({
    required HttpClient httpClient,
    required AggregatorMapper<BingNewsArticle> mapper,
    required Logger log,
  }) : _httpClient = httpClient,
       _mapper = mapper,
       _log = log;

  final HttpClient _httpClient;
  final AggregatorMapper<BingNewsArticle> _mapper;
  final Logger _log;

  @override
  Future<List<Headline>> fetchLatestHeadlines(
    Source source, {
    required Map<String, Topic> topicCache,
    required Topic fallbackTopic,
    required Map<String, Country> countryCache,
    required Map<String, String> mappingCache,
  }) async {
    final host = Uri.parse(source.url).host;
    _log.info('Fetching headlines from Bing for site: $host');

    try {
      // Bing News Search uses 'q' for queries. We search by source name.
      final request = BingNewsRequest(
        query: 'site:$host',
      );

      final response = await _httpClient.get<Map<String, dynamic>>(
        'search',
        queryParameters: request.toJson(),
      );

      _log.fine('Bing News response received. Parsing DTO...');
      final dto = BingNewsResponse.fromJson(response);
      _log.info('Bing News DTO parsed. Found ${dto.value.length} articles.');

      final headlines = <Headline>[];
      var failureCount = 0;

      for (final article in dto.value) {
        try {
          final headline = _mapper.mapToHeadline(
            article,
            source,
            topicCache: topicCache,
            fallbackTopic: fallbackTopic,
            countryCache: countryCache,
            mappingCache: mappingCache,
          );
          headlines.add(headline);
        } catch (e, s) {
          failureCount++;
          _log.warning('Failed to map Bing article: ${article.name}', e, s);
        }
      }

      _log.info(
        'Ingestion complete. Success: ${headlines.length}, Failed: $failureCount',
      );
      return headlines;
    } catch (e, s) {
      _log.severe('Critical failure fetching from Bing for $host', e, s);
      rethrow;
    }
  }
}
