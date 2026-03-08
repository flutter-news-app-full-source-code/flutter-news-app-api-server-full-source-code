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

    // Bing News Search uses 'q' for queries. We search by source name.
    final response = await _httpClient.get<Map<String, dynamic>>(
      'search',
      queryParameters: {
        'q': 'site:$host',
        'count': '20',
        'mkt': 'en-US',
        'safeSearch': 'Off',
      },
    );

    final dto = BingNewsResponse.fromJson(response);
    return dto.value
        .map(
          (a) => _mapper.mapToHeadline(
            a,
            source,
            topicCache: topicCache,
            fallbackTopic: fallbackTopic,
            countryCache: countryCache,
            mappingCache: mappingCache,
          ),
        )
        .toList();
  }
}
