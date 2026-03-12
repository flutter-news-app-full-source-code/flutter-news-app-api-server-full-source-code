import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:verity_api/src/models/ingestion/aggregator_catalog_source.dart';
import 'package:verity_api/src/models/ingestion/aggregator_source_mapping.dart';
import 'package:verity_api/src/models/ingestion/ingestion_candidate.dart';
import 'package:verity_api/src/models/ingestion/news_api_models.dart';
import 'package:verity_api/src/services/ingestion/mappers/aggregator_mapper.dart';
import 'package:verity_api/src/services/ingestion/providers/aggregator_provider.dart';

/// {@template news_api_aggregator_provider}
/// A concrete implementation of [AggregatorProvider] for NewsAPI.org.
/// {@endtemplate}
class NewsApiAggregatorProvider implements AggregatorProvider {
  /// {@macro news_api_aggregator_provider}
  const NewsApiAggregatorProvider({
    required HttpClient httpClient,
    required AggregatorMapper<NewsApiArticle> mapper,
    required Logger log,
  }) : _httpClient = httpClient,
       _mapper = mapper,
       _log = log;

  final HttpClient _httpClient;
  final AggregatorMapper<NewsApiArticle> _mapper;
  final Logger _log;

  static const String _kEverythingEndpoint = 'everything';
  static const String _kSourcesEndpoint = 'top-headlines/sources';

  /// NewsAPI strictly limits the 'sources' parameter to 20 identifiers.
  /// We use 10 to ensure a healthy volume of articles per source.
  static const int _kMaxBatchSize = 10;

  @override
  Future<List<AggregatorCatalogSource>> syncCatalog() async {
    _log.info('Syncing NewsAPI source catalog...');
    try {
      final response = await _fetch(
        _kSourcesEndpoint,
        {},
        NewsApiSourcesResponse.fromJson,
      );

      return response.sources
          .map(
            (s) => AggregatorCatalogSource(
              externalId: s.id,
              name: s.name,
              url: s.url,
              description: s.description,
            ),
          )
          .toList();
    } catch (e, s) {
      _log.severe('Failed to sync NewsAPI catalog.', e, s);
      rethrow;
    }
  }

  @override
  Future<Map<String, List<IngestionCandidate>>> fetchBatchHeadlines(
    List<AggregatorSourceMapping> mappings, {
    required Map<String, Source> sourceMap,
    required Map<String, Topic> topicCache,
    required Topic fallbackTopic,
    required Map<String, Country> countryCache,
    required Map<String, Topic> topicSlugMap,
    required Map<String, String> mappingCache,
  }) async {
    _log.info('Fetching NewsAPI headlines for ${mappings.length} sources...');
    final results = <String, List<IngestionCandidate>>{};

    // Chunk mappings to respect provider limits and ensure article density.
    for (var i = 0; i < mappings.length; i += _kMaxBatchSize) {
      final chunk = mappings.skip(i).take(_kMaxBatchSize).toList();
      final sourceIds = chunk.map((m) => m.externalId).join(',');

      _log.fine('Requesting batch for sources: $sourceIds');

      try {
        final request = NewsApiRequest(sources: sourceIds, pageSize: 100);
        final dto = await _fetch(
          _kEverythingEndpoint,
          request.toJson(),
          NewsApiResponse.fromJson,
        );

        _log.info('Batch received ${dto.articles.length} articles.');

        // Attribute articles back to internal Source IDs.
        for (final article in dto.articles) {
          final externalId = article.source.id;
          if (externalId == null) continue;

          // Find the mapping that matches this external ID.
          final mapping = chunk.firstWhere(
            (m) => m.externalId == externalId,
            orElse: () => chunk.first, // Fallback should not happen
          );

          final internalSource = sourceMap[mapping.sourceId];
          if (internalSource == null) continue;

          try {
            final headline = _mapper.mapToHeadline(
              article,
              internalSource,
              topicCache: topicCache,
              fallbackTopic: fallbackTopic,
              countryCache: countryCache,
              mappingCache: mappingCache,
            );

            results
                .putIfAbsent(mapping.sourceId, () => [])
                .add(
                  IngestionCandidate(
                    headline: headline,
                    rawDescription: article.description,
                  ),
                );
          } catch (e, s) {
            _log.warning(
              'Failed to map NewsAPI article: ${article.title}',
              e,
              s,
            );
          }
        }
      } catch (e, s) {
        _log.severe('Batch fetch failed for sources: $sourceIds', e, s);
        // We rethrow to trigger the "De-batching Fallback" in the service.
        rethrow;
      }
    }

    _log.info(
      'NewsAPI batch fetch complete. Attributed articles for '
      '${results.length} sources.',
    );
    return results;
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
