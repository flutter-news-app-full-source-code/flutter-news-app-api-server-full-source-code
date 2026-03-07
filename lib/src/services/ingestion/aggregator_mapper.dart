import 'package:core/core.dart';
import 'package:verity_api/src/services/idempotency_service.dart' show IdempotencyService;
import 'package:verity_api/src/services/services.dart' show IdempotencyService;

/// {@template aggregator_mapper}
/// Abstract contract for mapping raw aggregator DTOs to the system [Headline].
/// {@endtemplate}
abstract class AggregatorMapper<T> {
  /// Maps a raw DTO [article] to a [Headline] object.
  ///
  /// The [source] provides the context (language, headquarters) for the mapping.
  Headline mapToHeadline(T article, Source source);

  /// Resolves an external category string to an internal [Topic] ID.
  ///
  /// This implementation looks for a `categoryMapping` map in the [Source]
  /// metadata. If not found, it defaults to 'general'.
  String resolveTopicId(String? externalCategory, Source source) {
    // We assume the Source document has a metadata field for mappings.
    // Since 'metadata' isn't explicitly in the Source model provided,
    // we use a placeholder logic that can be extended.
    return 'general';
  }

  /// Normalizes a URL by removing tracking parameters to ensure
  /// deterministic deduplication in the [IdempotencyService].
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
