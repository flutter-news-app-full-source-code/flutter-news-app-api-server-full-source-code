import 'package:core/core.dart';
import 'package:logging/logging.dart';

/// {@template article_validator}
/// A utility class responsible for validating the quality and relevance of
/// incoming news articles before they are processed or persisted.
///
/// It enforces rules to prevent "spam", "junk", or "sibling leakage" (e.g.,
/// assigning an article from 'arabic.cnn.com' to the 'CNN' source which is
/// meant for 'edition.cnn.com').
/// {@endtemplate}
class ArticleValidator {
  static final _log = Logger('ArticleValidator');

  // Rejects known non-news patterns like TV schedules, weather, etc.
  static const _noisePatterns = [
    '/programmes/',
    '/schedules/',
    '/weather/',
    '/tv/',
    '/radio/',
    '/help/',
    '/contact/',
    '/terms',
    '/privacy',
    '/login',
    '/subscribe',
    '/newsletter',
  ];

  /// Validates the quality and relevance of a fetched article.
  ///
  /// Returns `true` if the article should be processed, `false` otherwise.
  static bool validate(Headline headline) {
    if (headline.url.isEmpty) {
      _log.info('[QC] Empty URL rejected.');
      return false;
    }

    final articleUrl = Uri.tryParse(headline.url);
    final sourceUrl = Uri.tryParse(headline.source.url);

    if (articleUrl == null || sourceUrl == null) {
      _log.info('[QC] Invalid URL format: ${headline.url}');
      return false;
    }

    // 1. Host Consistency Check (Prevents Sibling Leakage)
    // Ensures 'arabic.cnn.com' is not accepted for 'edition.cnn.com'.
    // Logic: Article host must contain the Source host (handling subdomains).
    // Normalization: strip 'www.' for comparison.
    final cleanArticleHost = articleUrl.host.replaceAll(RegExp(r'^www\.'), '');
    final cleanSourceHost = sourceUrl.host.replaceAll(RegExp(r'^www\.'), '');

    if (!cleanArticleHost.endsWith(cleanSourceHost)) {
      // Special Case: Allow if the source host is just a domain and article is subdomain
      // But reject if source is 'edition.cnn.com' and article is 'arabic.cnn.com'
      _log.info(
        '[QC] Host Mismatch (Leakage): Article="" does not end with Source="". URL: ${headline.url}',
      );
      return false;
    }

    // 2. Global Noise Filter (Path Blacklist)
    if (_noisePatterns.any(
      (pattern) => articleUrl.path.toLowerCase().contains(pattern),
    )) {
      _log.info(
        '[QC] Noise Pattern Detected: URL contains blacklist pattern. URL: ${headline.url}',
      );
      return false;
    }

    return true;
  }
}
