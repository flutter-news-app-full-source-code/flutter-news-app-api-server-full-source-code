import 'package:json_annotation/json_annotation.dart';

part 'news_api_models.g.dart';

/// {@template news_api_article}
/// Typed DTO for a single article returned by NewsAPI.org.
/// {@endtemplate}
@JsonSerializable(createToJson: false, checked: true)
class NewsApiArticle {
  /// {@macro news_api_article}
  const NewsApiArticle({
    required this.title,
    required this.url,
    required this.publishedAt,
    this.description,
    this.urlToImage,
  });

  /// Creates a [NewsApiArticle] from JSON.
  factory NewsApiArticle.fromJson(Map<String, dynamic> json) =>
      _$NewsApiArticleFromJson(json);

  /// The headline or title of the article.
  final String title;

  /// The direct URL to the article.
  final String url;

  /// A description or snippet from the article.
  final String? description;

  /// The URL to the article's main image.
  final String? urlToImage;

  /// The date and time the article was published.
  final DateTime publishedAt;
}

/// {@template news_api_response}
/// Typed DTO for the root NewsAPI.org response.
/// {@endtemplate}
@JsonSerializable(createToJson: false, checked: true)
class NewsApiResponse {
  /// {@macro news_api_response}
  const NewsApiResponse({
    required this.status,
    required this.totalResults,
    required this.articles,
  });

  /// Creates a [NewsApiResponse] from JSON.
  factory NewsApiResponse.fromJson(Map<String, dynamic> json) =>
      _$NewsApiResponseFromJson(json);

  /// The status of the request ('ok' or 'error').
  final String status;

  /// The total number of results available.
  final int totalResults;

  /// The list of articles returned.
  final List<NewsApiArticle> articles;
}

/// {@template news_api_request}
/// Strongly-typed request parameters for the NewsAPI.org 'everything' endpoint.
/// {@endtemplate}
@JsonSerializable(createFactory: false, includeIfNull: false)
class NewsApiRequest {
  /// {@macro news_api_request}
  const NewsApiRequest({
    this.sources,
    this.domains,
    this.pageSize = 20,
    this.sortBy = 'publishedAt',
  }) : assert(
         sources != null || domains != null,
         'Either sources or domains must be provided.',
       ),
       assert(
         sources == null || domains == null,
         'Cannot provide both sources and domains.',
       );

  /// A comma-separated list of source identifiers.
  final String? sources;

  /// A comma-separated list of domains to search.
  final String? domains;

  /// The number of results to return per page.
  final int pageSize;

  /// The order to sort the articles in.
  final String sortBy;

  /// Converts the request to a map of query parameters.
  /// Note: 'apiKey' is injected by the HTTP client interceptor or header.
  Map<String, dynamic> toJson() => _$NewsApiRequestToJson(this);
}
