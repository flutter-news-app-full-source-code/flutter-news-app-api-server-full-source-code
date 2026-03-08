import 'package:json_annotation/json_annotation.dart';

part 'mediastack_models.g.dart';

/// {@template mediastack_article}
/// Typed DTO for a single article returned by the MediaStack API.
/// {@endtemplate}
@JsonSerializable(createToJson: false, checked: true)
class MediaStackArticle {
  /// {@macro mediastack_article}
  const MediaStackArticle({
    required this.title,
    required this.url,
    required this.description,
    required this.image,
    required this.publishedAt,
    required this.category,
    required this.language,
    required this.country,
  });

  /// Creates a [MediaStackArticle] from JSON.
  factory MediaStackArticle.fromJson(Map<String, dynamic> json) =>
      _$MediaStackArticleFromJson(json);

  /// The title of the article.
  final String title;

  /// The canonical URL of the article.
  final String url;

  /// A brief summary or description.
  final String description;

  /// The URL to the main image, if available.
  final String? image;

  /// The timestamp when the article was published.
  @JsonKey(name: 'published_at')
  final DateTime publishedAt;

  /// The category assigned by MediaStack (e.g., 'business').
  final String category;

  /// The language code (e.g., 'en').
  final String language;

  /// The country code (e.g., 'us').
  final String country;
}

/// {@template mediastack_response}
/// Typed DTO for the root MediaStack API response.
/// {@endtemplate}
@JsonSerializable(createToJson: false, checked: true)
class MediaStackResponse {
  /// {@macro mediastack_response}
  const MediaStackResponse({
    required this.data,
  });

  /// Creates a [MediaStackResponse] from JSON.
  factory MediaStackResponse.fromJson(Map<String, dynamic> json) =>
      _$MediaStackResponseFromJson(json);

  /// The list of articles returned by the API.
  final List<MediaStackArticle> data;
}

/// {@template mediastack_request}
/// Strongly-typed request parameters for the MediaStack API.
/// {@endtemplate}
@JsonSerializable(createFactory: false)
class MediaStackRequest {
  /// {@macro mediastack_request}
  const MediaStackRequest({
    required this.sources,
    required this.languages,
    this.limit = 20,
  });

  /// A comma-separated list of source identifiers.
  final String sources;

  /// A comma-separated list of language codes (e.g., 'en').
  final String languages;

  /// The number of results to return.
  final int limit;

  /// Converts the request to a map of query parameters.
  /// Note: 'access_key' is injected by the HTTP client interceptor.
  Map<String, dynamic> toJson() => _$MediaStackRequestToJson(this);
}
