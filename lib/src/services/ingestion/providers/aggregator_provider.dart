import 'dart:async';

import 'package:core/core.dart';
import 'package:verity_api/src/models/ingestion/aggregator_catalog_source.dart';
import 'package:verity_api/src/models/ingestion/aggregator_source_mapping.dart';

/// {@template aggregator_provider}
/// Abstract contract for external news aggregator integrations.
///
/// Implementations are responsible for the low-level HTTP communication
/// with specific aggregator APIs (e.g., Google News, NewsAPI) and mapping
/// their proprietary JSON structures into the system's [Headline] model.
/// {@endtemplate}
abstract class AggregatorProvider {
  /// Fetches the entire list of supported sources from the provider.
  /// Used for on-demand discovery and mapping.
  Future<List<AggregatorCatalogSource>> syncCatalog();

  /// Fetches headlines for a batch of sources in a single request.
  ///
  /// [mappings] provides the link between internal Source IDs and external IDs.
  /// [sourceMap] provides the full Source entities for mapping context.
  ///
  /// Returns a Map where the key is the internal Source ID and the value
  /// is the list of headlines fetched for that source.
  Future<Map<String, List<Headline>>> fetchBatchHeadlines(
    List<AggregatorSourceMapping> mappings, {
    required Map<String, Source> sourceMap,
    required Map<String, Topic> topicCache,
    required Topic fallbackTopic,
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
  const DefaultAggregatorProvider();

  @override
  Future<List<AggregatorCatalogSource>> syncCatalog() async => [];

  @override
  Future<Map<String, List<Headline>>> fetchBatchHeadlines(
    List<AggregatorSourceMapping> mappings, {
    required Map<String, Source> sourceMap,
    required Map<String, Topic> topicCache,
    required Topic fallbackTopic,
    required Map<String, Country> countryCache,
    required Map<String, String> mappingCache,
  }) async => {};
}
