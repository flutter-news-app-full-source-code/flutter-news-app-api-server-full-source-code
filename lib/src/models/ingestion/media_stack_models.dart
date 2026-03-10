import 'package:json_annotation/json_annotation.dart';

part 'media_stack_models.g.dart';

/// {@template media_stack_article}
/// Typed DTO for a single article returned by MediaStack.
/// {@endtemplate}
@JsonSerializable(
  createToJson: false,
  checked: true,
  fieldRename: FieldRename.snake,
)
class MediaStackArticle {
  /// {@macro media_stack_article}
  const MediaStackArticle({
    required this.title,
    required this.url,
    required this.source,
    required this.category,
    required this.language,
    required this.country,
    required this.publishedAt,
    this.author,
    this.description,
    this.image,
  });

  /// Creates a [MediaStackArticle] from JSON.
  factory MediaStackArticle.fromJson(Map<String, dynamic> json) =>
      _$MediaStackArticleFromJson(json);

  /// The author of the article.
  final String? author;

  /// The headline or title.
  final String title;

  /// A brief description.
  final String? description;

  /// The direct URL.
  final String url;

  /// The name of the source.
  final String source;

  /// The URL to the main image.
  final String? image;

  /// The category string (e.g., 'business').
  final String category;

  /// The language code.
  final String language;

  /// The country code.
  final String country;

  /// The publication timestamp.
  final DateTime publishedAt;
}

/// {@template media_stack_pagination}
/// Pagination metadata for MediaStack responses.
/// {@endtemplate}
@JsonSerializable(createToJson: false, checked: true)
class MediaStackPagination {
  /// {@macro media_stack_pagination}
  const MediaStackPagination({
    required this.limit,
    required this.offset,
    required this.count,
    required this.total,
  });

  /// Creates a [MediaStackPagination] from JSON.
  factory MediaStackPagination.fromJson(Map<String, dynamic> json) =>
      _$MediaStackPaginationFromJson(json);

  /// The number of results per page.
  final int limit;

  /// The offset for pagination.
  final int offset;

  /// The number of items in the current response.
  final int count;

  /// The total number of items available.
  final int total;
}

/// {@template media_stack_response}
/// Typed DTO for the root MediaStack /news response.
/// {@endtemplate}
@JsonSerializable(createToJson: false, checked: true)
class MediaStackResponse {
  /// {@macro media_stack_response}
  const MediaStackResponse({
    required this.pagination,
    required this.data,
  });

  /// Creates a [MediaStackResponse] from JSON.
  factory MediaStackResponse.fromJson(Map<String, dynamic> json) =>
      _$MediaStackResponseFromJson(json);

  /// Pagination metadata.
  final MediaStackPagination pagination;

  /// The list of articles.
  final List<MediaStackArticle> data;
}

/// {@template media_stack_source}
/// Typed DTO for a source returned by MediaStack /sources.
/// {@endtemplate}
@JsonSerializable(createToJson: false, checked: true)
class MediaStackSource {
  /// {@macro media_stack_source}
  const MediaStackSource({
    required this.name,
    required this.url,
    required this.category,
    required this.language,
    required this.country,
  });

  /// Creates a [MediaStackSource] from JSON.
  factory MediaStackSource.fromJson(Map<String, dynamic> json) =>
      _$MediaStackSourceFromJson(json);

  /// The name of the source (used as identifier in MediaStack).
  final String name;

  /// The homepage URL.
  final String url;

  /// The primary category.
  final String category;

  /// The language code.
  final String language;

  /// The country code.
  final String country;
}

/// {@template media_stack_sources_response}
/// Typed DTO for the MediaStack /sources response.
/// {@endtemplate}
@JsonSerializable(createToJson: false, checked: true)
class MediaStackSourcesResponse {
  /// {@macro media_stack_sources_response}
  const MediaStackSourcesResponse({required this.data});

  /// Creates a [MediaStackSourcesResponse] from JSON.
  factory MediaStackSourcesResponse.fromJson(Map<String, dynamic> json) =>
      _$MediaStackSourcesResponseFromJson(json);

  /// The list of supported sources.
  final List<MediaStackSource> data;
}
