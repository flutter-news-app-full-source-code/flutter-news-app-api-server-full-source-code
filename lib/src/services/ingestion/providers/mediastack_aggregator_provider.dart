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

  static const String _kEndpoint = 'news';

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

    try {
      // MediaStack uses 'sources' parameter for filtering.
      final request = MediaStackRequest(
        sources: sourceId,
        languages: source.language.name,
      );

      _log.fine('MediaStack request prepared. Fetching DTO...');
      final dto = await _fetch(
        _kEndpoint,
        request.toJson(),
        MediaStackResponse.fromJson,
      );
      _log.info('MediaStack DTO parsed. Found ${dto.data.length} articles.');

      final headlines = <Headline>[];
      var failureCount = 0;

      for (final article in dto.data) {
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
          _log.warning(
            'Failed to map MediaStack article: ${article.title}',
            e,
            s,
          );
        }
      }

      _log.info(
        'Ingestion complete. Success: ${headlines.length}, Failed: $failureCount',
      );
      return headlines;
    } catch (e, s) {
      _log.severe(
        'Critical failure fetching from MediaStack for $sourceId',
        e,
        s,
      );
      rethrow;
    }
  }

  Future<T> _fetch<T>(
    String endpoint,
    Map<String, dynamic> queryParameters,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final response = await _httpClient.get<Map<String, dynamic>>(
      endpoint,
      queryParameters: queryParameters,
    );
    return fromJson(response);
  }
}
