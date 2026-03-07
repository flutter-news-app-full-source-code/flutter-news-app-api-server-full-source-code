/// {@template topic_resolver}
/// A registry-based resolver for mapping external aggregator categories
/// to internal system Topic IDs.
/// {@endtemplate}
class TopicResolver {
  /// {@macro topic_resolver}
  const TopicResolver({
    required Map<String, String> mediaStackMapping,
    required Map<String, String> bingMapping,
    required Map<String, String> newsApiMapping,
  }) : _mediaStackMapping = mediaStackMapping,
       _bingMapping = bingMapping,
       _newsApiMapping = newsApiMapping;

  final Map<String, String> _mediaStackMapping;
  final Map<String, String> _bingMapping;
  final Map<String, String> _newsApiMapping;

  /// Resolves a MediaStack category to an internal Topic ID.
  String fromMediaStack(String? category) =>
      _mediaStackMapping[category?.toLowerCase()] ?? 'topic-general-uuid';

  /// Resolves a Bing category to an internal Topic ID.
  String fromBing(String? category) =>
      _bingMapping[category] ?? 'topic-general-uuid';

  /// Resolves a NewsAPI category to an internal Topic ID.
  String fromNewsApi(String? category) =>
      _newsApiMapping[category?.toLowerCase()] ?? 'topic-general-uuid';
}
