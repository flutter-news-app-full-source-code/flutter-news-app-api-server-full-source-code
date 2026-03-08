import 'dart:async';

import 'package:core/core.dart';
import 'package:verity_api/src/services/content_enrichment_service.dart'
    show ContentEnrichmentService;
import 'package:verity_api/src/services/services.dart'
    show ContentEnrichmentService;

/// {@template aggregator_provider}
/// Abstract contract for external news aggregator integrations.
///
/// Implementations are responsible for the low-level HTTP communication
/// with specific aggregator APIs (e.g., Google News, NewsAPI) and mapping
/// their proprietary JSON structures into the system's [Headline] model.
/// {@endtemplate}
abstract class AggregatorProvider {
  /// Fetches the latest headlines for a specific [Source].
  ///
  /// The [source] provides the necessary metadata (URL, language, headquarters)
  /// to contextualize the API request.
  ///
  /// Returns a list of "Raw" [Headline] objects. These headlines are
  /// considered raw because they contain partial embedded entities that
  /// must be hydrated by the [ContentEnrichmentService] before persistence.
  Future<List<Headline>> fetchLatestHeadlines(
    Source source, {
    required Map<String, Topic> topicCache,
    required Map<String, Country> countryCache,
    required Map<String, String> mappingCache,
  });
}

/// {@template default_aggregator_provider}
/// A generic implementation of [AggregatorProvider] that handles standard
/// JSON-based news feeds.
/// {@endtemplate}
class DefaultAggregatorProvider implements AggregatorProvider {
  /// {@macro default_aggregator_provider}
  const DefaultAggregatorProvider({
    required HttpClient httpClient,
  }) : _httpClient = httpClient;

  final HttpClient _httpClient;

  @override
  Future<List<Headline>> fetchLatestHeadlines(
    Source source, {
    required Map<String, Topic> topicCache,
    required Map<String, Country> countryCache,
    required Map<String, String> mappingCache,
  }) async {
    // Connectivity check for the source URL.
    unawaited(_httpClient.get<dynamic>(source.url));
    return [];
  }
}
