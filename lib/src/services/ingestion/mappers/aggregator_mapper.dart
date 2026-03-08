import 'package:core/core.dart';

/// {@template aggregator_mapper}
/// Abstract contract for mapping raw aggregator DTOs to the system [Headline].
/// {@endtemplate}
abstract class AggregatorMapper<T> {
  /// Maps a raw DTO [article] to a [Headline] object.
  Headline mapToHeadline(
    T article,
    Source source, {
    required Map<String, Topic> topicCache,
    required Topic fallbackTopic,
    required Map<String, Country> countryCache,
    required Map<String, String> mappingCache,
  });

  /// Resolves a Topic from the cache using the DB-driven mapping table.
  Topic resolveTopic(
    String? externalCategory,
    Map<String, Topic> topicCache,
    Topic fallbackTopic,
    Map<String, String> mappingCache,
  ) {
    final topicId = mappingCache[externalCategory?.toLowerCase()];

    if (topicId != null && topicCache.containsKey(topicId)) {
      return topicCache[topicId]!;
    }

    return fallbackTopic;
  }

  /// Resolves a Country from the cache using ISO code.
  Country resolveCountry(
    String? isoCode,
    Map<String, Country> countryCache,
    Country fallback,
  ) {
    if (isoCode == null) return fallback;
    return countryCache[isoCode.toLowerCase()] ?? fallback;
  }

  /// Normalizes a URL by removing tracking parameters.
  String normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasQuery) return url;

      final cleanQuery = Map<String, String>.from(uri.queryParameters)
        ..removeWhere(
          (key, _) => key.startsWith('utm_') || key == 'ref' || key == 'source',
        );

      return uri.replace(queryParameters: cleanQuery).toString();
    } catch (_) {
      return url;
    }
  }
}
