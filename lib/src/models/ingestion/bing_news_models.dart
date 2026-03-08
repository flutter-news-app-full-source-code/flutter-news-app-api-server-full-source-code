import 'package:json_annotation/json_annotation.dart';

part 'bing_news_models.g.dart';

/// {@template bing_news_article}
/// Typed DTO for a single article returned by the Bing News API.
/// {@endtemplate}
@JsonSerializable(createToJson: false, checked: true)
class BingNewsArticle {
  /// {@macro bing_news_article}
  const BingNewsArticle({
    required this.name,
    required this.url,
    required this.description,
    required this.datePublished,
    this.category,
    this.imageThumbnailUrl,
    this.provider,
  });

  /// Creates a [BingNewsArticle] from JSON.
  factory BingNewsArticle.fromJson(Map<String, dynamic> json) =>
      _$BingNewsArticleFromJson(json);

  /// The name/title of the news article.
  final String name;

  /// The URL to the article.
  final String url;

  /// A summary of the article content.
  final String description;

  /// The date and time the article was published.
  final DateTime datePublished;

  /// The category assigned by Bing (e.g., 'ScienceAndTechnology').
  final String? category;

  /// The URL to the thumbnail image.
  @JsonKey(name: 'image', readValue: _readImageThumbnail)
  final String? imageThumbnailUrl;

  /// The provider organization (source) of the article.
  @JsonKey(name: 'provider', readValue: _readProviderName)
  final String? provider;
}

Object? _readImageThumbnail(Map<dynamic, dynamic> json, String key) {
  return json['image']?['thumbnail']?['contentUrl'];
}

Object? _readProviderName(Map<dynamic, dynamic> json, String key) {
  final providers = json['provider'] as List?;
  return (providers != null && providers.isNotEmpty)
      ? providers.first['name']
      : null;
}

/// {@template bing_news_response}
/// Typed DTO for the root Bing News API response.
/// {@endtemplate}
@JsonSerializable(createToJson: false, checked: true)
class BingNewsResponse {
  /// {@macro bing_news_response}
  const BingNewsResponse({
    required this.value,
  });

  /// Creates a [BingNewsResponse] from JSON.
  factory BingNewsResponse.fromJson(Map<String, dynamic> json) =>
      _$BingNewsResponseFromJson(json);

  /// The list of news articles returned by Bing.
  final List<BingNewsArticle> value;
}

/// {@template bing_news_request}
/// Strongly-typed request parameters for the Bing News Search API.
/// {@endtemplate}
@JsonSerializable(createFactory: false)
class BingNewsRequest {
  /// {@macro bing_news_request}
  const BingNewsRequest({
    required this.query,
    this.count = 20,
    this.market = 'en-US',
    this.safeSearch = 'Off',
  });

  /// The user's search query string.
  /// Corresponds to the 'q' parameter.
  @JsonKey(name: 'q')
  final String query;

  /// The number of results to return (1-100).
  @JsonKey(name: 'count')
  final int count;

  /// The market code to use for the request (e.g., 'en-US').
  @JsonKey(name: 'mkt')
  final String market;

  /// Filter for adult content ('Off', 'Moderate', 'Strict').
  final String safeSearch;

  /// Converts the request to a map of query parameters.
  Map<String, dynamic> toJson() => _$BingNewsRequestToJson(this);
}
