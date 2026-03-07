import 'package:core/core.dart';
import 'package:verity_api/src/models/ingestion/bing_news_models.dart';
import 'package:verity_api/src/models/ingestion/mediastack_models.dart';
import 'package:verity_api/src/models/ingestion/news_api_models.dart';
import 'package:verity_api/src/services/content_enrichment_service.dart' show ContentEnrichmentService;
import 'package:verity_api/src/services/ingestion/aggregator_mapper.dart';
import 'package:verity_api/src/services/services.dart' show ContentEnrichmentService;

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
  Future<List<Headline>> fetchLatestHeadlines(Source source);
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
  Future<List<Headline>> fetchLatestHeadlines(Source source) async {
    // Default provider performs a simple ping to verify connectivity.
    // In production, this would handle generic JSON/Atom feeds if needed.
    // Note: RSS is explicitly excluded per requirements.
    _httpClient.get<dynamic>(source.url);
    return [];
  }
}

/// {@template news_api_aggregator_provider}
/// A concrete implementation of [AggregatorProvider] for NewsAPI.org.
/// {@endtemplate}
class NewsApiAggregatorProvider implements AggregatorProvider {
  /// {@macro news_api_aggregator_provider}
  const NewsApiAggregatorProvider({
    required HttpClient httpClient,
    required AggregatorMapper<NewsApiArticle> mapper,
  }) : _httpClient = httpClient,
       _mapper = mapper;

  final HttpClient _httpClient;
  final AggregatorMapper<NewsApiArticle> _mapper;

  @override
  Future<List<Headline>> fetchLatestHeadlines(Source source) async {
    try {
      final response = await _httpClient.get<Map<String, dynamic>>(
        'everything',
        queryParameters: {
          'sources': source.url.split('/').last,
          'pageSize': '20',
          'sortBy': 'publishedAt',
        },
      );

      final dto = NewsApiResponse.fromJson(response);
      return dto.articles.map((a) => _mapper.mapToHeadline(a, source)).toList();
    } catch (e) {
      return [];
    }
  }
}

/// {@template mediastack_aggregator_provider}
/// A concrete implementation of [AggregatorProvider] for MediaStack.
/// {@endtemplate}
class MediaStackAggregatorProvider implements AggregatorProvider {
  /// {@macro mediastack_aggregator_provider}
  const MediaStackAggregatorProvider({
    required HttpClient httpClient,
    required AggregatorMapper<MediaStackArticle> mapper,
  }) : _httpClient = httpClient,
       _mapper = mapper;

  final HttpClient _httpClient;
  final AggregatorMapper<MediaStackArticle> _mapper;

  @override
  Future<List<Headline>> fetchLatestHeadlines(Source source) async {
    try {
      // MediaStack uses 'sources' parameter for filtering.
      final response = await _httpClient.get<Map<String, dynamic>>(
        'news',
        queryParameters: {
          'sources': source.url.split('/').last,
          'limit': '20',
          'languages': source.language.name,
        },
      );

      final dto = MediaStackResponse.fromJson(response);
      return dto.data.map((a) => _mapper.mapToHeadline(a, source)).toList();
    } catch (e) {
      return [];
    }
  }
}

/// {@template bing_aggregator_provider}
/// A concrete implementation of [AggregatorProvider] for Bing News.
/// {@endtemplate}
class BingNewsAggregatorProvider implements AggregatorProvider {
  /// {@macro bing_aggregator_provider}
  const BingNewsAggregatorProvider({
    required HttpClient httpClient,
    required AggregatorMapper<BingNewsArticle> mapper,
  }) : _httpClient = httpClient,
       _mapper = mapper;

  final HttpClient _httpClient;
  final AggregatorMapper<BingNewsArticle> _mapper;

  @override
  Future<List<Headline>> fetchLatestHeadlines(Source source) async {
    try {
      // Bing News Search uses 'q' for queries. We search by source name.
      final response = await _httpClient.get<Map<String, dynamic>>(
        'search',
        queryParameters: {
          'q': 'site:${Uri.parse(source.url).host}',
          'count': '20',
          'mkt': 'en-US',
          'safeSearch': 'Off',
        },
      );

      final dto = BingNewsResponse.fromJson(response);
      return dto.value.map((a) => _mapper.mapToHeadline(a, source)).toList();
    } catch (e) {
      return [];
    }
  }
}
