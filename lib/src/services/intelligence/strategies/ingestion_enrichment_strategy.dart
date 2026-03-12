import 'package:core/core.dart';
import 'package:verity_api/src/models/ingestion/ingestion_candidate.dart';
import 'package:verity_api/src/services/intelligence/strategies/ai_strategy.dart';

/// Result of the AI processing for a single headline in a batch.
typedef AiEnrichmentResult = ({
  bool isNews,
  String? topicSlug,
  List<String> extractedPersons,
  List<String> extractedCountryCodes,
  double breakingConfidence,
  Map<SupportedLanguage, String> translations,
});

/// {@template ingestion_enrichment_strategy}
/// Strategy for batch processing headlines during automated ingestion.
///
/// It performs junk filtering, topic inference, person extraction,
/// breaking news scoring, and multi-language translation in one pass.
/// {@endtemplate}
class IngestionEnrichmentStrategy
    extends
        AiStrategy<List<IngestionCandidate>, Map<String, AiEnrichmentResult>> {
  @override
  String get identifier => 'batch_ingestion';

  @override
  List<Map<String, String>> buildPrompt(
    List<IngestionCandidate> input, {
    required List<SupportedLanguage> enabledLanguages,
    List<String> predefinedChoices = const [],
  }) {
    final languages = enabledLanguages.map((e) => e.name).join(', ');

    // We send a minimal representation to save input tokens.
    final items = input
        .map(
          (c) => {
            'id': c.headline.id,
            'title': c.headline.title.values.first,
            // Provide description for better context, if available.
            'description': c.rawDescription,
          },
        )
        .toList();

    return [
      {
        'role': 'system',
        'content':
            '''
You are an expert news analyst and translator. Analyze the provided articles and return a JSON object where keys are the article IDs.
For each article, provide:
1. "isNews": A boolean. It MUST be `false` if the content is a list of links, a weather report, a stock ticker, an ad, a navigational element, or any other non-story content. It must be `true` only for a standard news article.
2. "topicSlug": A string. From this exact list, select the single most relevant topic slug: [$predefinedChoices]. If none are a perfect match, choose the closest one. A result is mandatory.
3. "extractedPersons": A list of strings, containing the full names of any public figures mentioned (e.g., politicians, CEOs).
4. "extractedCountryCodes": A list of 2-letter ISO 3166-1 country codes (e.g. "US", "FR") for countries mentioned in the article.
5. "breakingConfidence": A float from 0.0 to 1.0 indicating how likely this is to be urgent, breaking news.
6. "translations": A dictionary translating the original title into these languages: [$languages].

Return ONLY valid JSON.
''',
      },
      {
        'role': 'user',
        'content': 'Headlines to process: ${input.length} items. Data: $items',
      },
    ];
  }

  @override
  Map<String, AiEnrichmentResult> mapResponse(
    Map<String, dynamic> data,
    List<IngestionCandidate> input,
  ) {
    final results = <String, AiEnrichmentResult>{};

    for (final entry in data.entries) {
      final id = entry.key;
      final val = entry.value as Map<String, dynamic>;

      results[id] = (
        isNews: val['isNews'] as bool? ?? true,
        topicSlug: val['topicSlug'] as String?,
        extractedPersons: List<String>.from(
          val['extractedPersons'] as List? ?? [],
        ),
        extractedCountryCodes: List<String>.from(
          val['extractedCountryCodes'] as List? ?? [],
        ),
        breakingConfidence:
            (val['breakingConfidence'] as num?)?.toDouble() ?? 0,
        translations: _parseTranslations(val['translations']),
      );
    }

    return results;
  }

  Map<SupportedLanguage, String> _parseTranslations(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map((k, v) {
      try {
        return MapEntry(
          SupportedLanguage.values.byName(k as String),
          v as String,
        );
      } catch (_) {
        return MapEntry(SupportedLanguage.en, v as String);
      }
    });
  }
}
