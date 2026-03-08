import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:verity_api/src/models/ingestion/ingestion.dart';
import 'package:verity_api/src/services/ingestion/ingestion.dart'
    show AggregatorProvider;
import 'package:verity_api/src/services/ingestion/mappers/aggregator_mapper.dart';
import 'package:verity_api/src/services/ingestion/providers/aggregator_provider.dart'
    show AggregatorProvider;
import 'package:verity_api/src/services/services.dart' show AggregatorProvider;

/// {@template mediastack_aggregator_provider}
/// A concrete implementation of [AggregatorProvider] for MediaStack.
/// {@endtemplate}
class MediaStackAggregatorProvider implements AggregatorProvider {
  /// {@macro mediastack_aggregator_provider}
  const MediaStackAggregatorProvider({
    required HttpClient httpClient,
    required AggregatorMapper<MediaStackArticle> mapper,
    required Logger log,
  }) : _httpClient = httpClient,
       _mapper = mapper,
       _log = log;

  final HttpClient _httpClient;
  final AggregatorMapper<MediaStackArticle> _mapper;
  final Logger _log;

  @override
  Future<List<Headline>> fetchLatestHeadlines(
    Source source, {
    required Map<String, Topic> topicCache,
    required Topic fallbackTopic,
    required Map<String, Country> countryCache,
    required Map<String, String> mappingCache,
  }) async {
    final sourceId = source.url.split('/').last;
    _log.info('Fetching headlines from MediaStack for source: $sourceId');

    // MediaStack uses 'sources' parameter for filtering.
    final response = await _httpClient.get<Map<String, dynamic>>(
      'news',
      queryParameters: {
        'sources': sourceId,
        'limit': '20',
        'languages': source.language.name,
      },
    );

    final dto = MediaStackResponse.fromJson(response);
    return dto.data
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
