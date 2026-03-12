import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:verity_api/src/models/ingestion/aggregator_catalog_source.dart';
import 'package:verity_api/src/models/ingestion/aggregator_source_mapping.dart';
import 'package:verity_api/src/models/ingestion/ingestion_candidate.dart';
import 'package:verity_api/src/models/ingestion/media_stack_models.dart';
import 'package:verity_api/src/services/ingestion/mappers/aggregator_mapper.dart';
import 'package:verity_api/src/services/ingestion/providers/aggregator_provider.dart';

/// {@template media_stack_aggregator_provider}
/// A concrete implementation of [AggregatorProvider] for MediaStack.
/// {@endtemplate}
class MediaStackAggregatorProvider implements AggregatorProvider {
  /// {@macro media_stack_aggregator_provider}
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

  static const String _kNewsEndpoint = 'news';
  static const String _kSourcesEndpoint = 'sources';

  /// MediaStack allows many sources, but we chunk to 10 for density.
  static const int _kMaxBatchSize = 10;

  @override
  Future<List<AggregatorCatalogSource>> syncCatalog() async {
    _log.info('Syncing MediaStack source catalog...');
    try {
      final response = await _fetch(
        _kSourcesEndpoint,
        {},
        MediaStackSourcesResponse.fromJson,
      );

      return response.data
          .map(
            (s) => AggregatorCatalogSource(
              externalId: s.name, // MediaStack uses names as identifiers
              name: s.name,
              url: s.url,
            ),
          )
          .toList();
    } catch (e, s) {
      _log.severe('Failed to sync MediaStack catalog.', e, s);
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
    _log.info(
      'Fetching MediaStack headlines for ${mappings.length} sources...',
    );
    final results = <String, List<IngestionCandidate>>{};

    for (var i = 0; i < mappings.length; i += _kMaxBatchSize) {
      final chunk = mappings.skip(i).take(_kMaxBatchSize).toList();
      final sourceNames = chunk.map((m) => m.externalId).join(',');

      _log.fine('Requesting MediaStack batch for sources: $sourceNames');

      try {
        final dto = await _fetch(
          _kNewsEndpoint,
          {'sources': sourceNames, 'limit': 100},
          MediaStackResponse.fromJson,
        );

        _log.info('MediaStack batch received ${dto.data.length} articles.');

        for (final article in dto.data) {
          final mapping = chunk.firstWhere(
            (m) => m.externalId.toLowerCase() == article.source.toLowerCase(),
            orElse: () => chunk.first,
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
              'Failed to map MediaStack article: ${article.title}',
              e,
              s,
            );
          }
        }
      } catch (e, s) {
        _log.severe('MediaStack batch fetch failed.', e, s);
        rethrow;
      }
    }

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
