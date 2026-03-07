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
  final String? imageThumbnailUrl;
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
