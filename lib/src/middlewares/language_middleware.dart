import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';

final _log = Logger('LanguageMiddleware');

/// Middleware that resolves the client's preferred language from the
/// `Accept-Language` header and provides it to the request context.
///
/// It attempts to match the header value against the [SupportedLanguage] enum.
/// If no match is found or the header is missing, it falls back to
/// [SupportedLanguage.en].
Middleware languageProvider() {
  return (handler) {
    return (context) {
      // --- JWT Claim Priority Check ---
      // First, check if a SupportedLanguage was already provided by the
      // authentication middleware (from a JWT 'lang' claim).
      try {
        final languageFromJwt = context.read<SupportedLanguage>();
        _log.finer('Using language from JWT claim: ${languageFromJwt.name}');
        return handler(context);
      } catch (_) {
        // SupportedLanguage not provided by upstream, proceed to resolve from header.
      }

      final acceptLanguage = context.request.headers['Accept-Language'];
      var resolvedLanguage = SupportedLanguage.en; // Default fallback

      if (acceptLanguage != null && acceptLanguage.isNotEmpty) {
        // Simple parsing: take the first language code (e.g., "en-US,en;q=0.9")
        // and try to match the primary subtag.
        final primaryTag = acceptLanguage.split(',').first.split(';').first;
        // Handle "en-US" -> "en"
        final languageCode = primaryTag.split('-').first.toLowerCase();

        try {
          resolvedLanguage = SupportedLanguage.values.byName(languageCode);
        } catch (_) {
          _log.finer(
            'Unsupported language code "$languageCode" in header. '
            'Using default: ${resolvedLanguage.name}',
          );
        }
      }

      _log.finer(
        'Resolved language: ${resolvedLanguage.name} '
        '(Header: "$acceptLanguage")',
      );

      return handler(
        context.provide<SupportedLanguage>(() => resolvedLanguage),
      );
    };
  };
}
