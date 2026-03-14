import 'package:core/core.dart';
import 'package:veritai_api/src/services/intelligence/strategies/ai_strategy.dart';

/// Result of the AI processing for a single headline in a batch.
typedef AiEnrichmentResult = ({
  bool isNews,
  String? topicSlug,
  List<Person> extractedPersons,
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
    extends AiStrategy<List<Headline>, Map<String, AiEnrichmentResult>> {
  @override
  String get identifier => 'batch_ingestion';

  @override
  List<Map<String, String>> buildPrompt(
    List<Headline> input, {
    required List<SupportedLanguage> enabledLanguages,
    List<String> predefinedChoices = const [],
  }) {
    final languages = enabledLanguages.map((e) => e.name).join(', ');

    // We send a minimal representation to save input tokens.
    final items = input
        .map(
          (h) => {
            'id': h.id,
            'title': h.title.values.first,
          },
        )
        .toList();

    return [
      {
        'role': 'system',
        'content':
            '''
You are a news analysis and translation engine. Your task is to process a batch of news headlines and return a single, valid JSON object. The keys of this object MUST be the article IDs from the input.

For each article ID, the value MUST be a JSON object with the following strict schema:
1.  `isNews` (boolean): `true` if the content is a standard news article. `false` if it is a list, advertisement, weather report, or other non-story content.
2.  `topicSlug` (string | null): The single most relevant topic slug from this list: [$predefinedChoices]. You MUST NOT invent slugs. If no topic matches, return `null`.
3.  `extractedPersons` (array of objects): An array of all public figures mentioned. Each object in the array MUST have the following structure:
    - `name` (object): A dictionary mapping language codes to the person's FULL NAME.
    - `description` (object): A dictionary mapping language codes to a brief, factual description of the person's role (e.g., "CEO of X", "Senator from Y"). If the role is unknown, use "...". The required languages for these translations are: [$languages].
4.  `extractedCountryCodes` (array of strings): A list of 2-letter ISO 3166-1 country codes (e.g., "US", "FR") for any mentioned countries.
5.  `breakingConfidence` (float): A number between 0.0 and 1.0 indicating the likelihood of this being urgent, breaking news.
6.  `translations` (object): A dictionary translating the original headline title into these languages: [$languages].

EXAMPLE of a single entry in the output JSON:
"article-123": {
  "isNews": true,
  "topicSlug": "Technology",
  "extractedPersons": [],
  "extractedCountryCodes": ["US"],
  "breakingConfidence": 0.2,
  "translations": { "es": "Microsoft anuncia nuevo chip de IA." }
}

Return ONLY the valid JSON object. Do not include any other text or explanations.
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
    List<Headline> input,
    List<SupportedLanguage> enabledLanguages,
  ) {
    final results = <String, AiEnrichmentResult>{};

    for (final entry in data.entries) {
      final id = entry.key;
      final val = entry.value as Map<String, dynamic>;

      results[id] = (
        isNews: val['isNews'] as bool? ?? true,
        topicSlug: val['topicSlug'] as String?,
        extractedPersons: _parsePersons(
          val['extractedPersons'] as List? ?? [],
          enabledLanguages,
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

  List<Person> _parsePersons(
    List<dynamic> raw,
    List<SupportedLanguage> enabledLanguages,
  ) {
    return raw.map((e) {
      final map = e as Map<String, dynamic>;
      return Person(
        id: 'temp',
        name: _parseGenericTranslations(map['name'], enabledLanguages),
        description: _parseGenericTranslations(
          map['description'],
          enabledLanguages,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      );
    }).toList();
  }

  Map<SupportedLanguage, String> _parseGenericTranslations(
    dynamic raw,
    List<SupportedLanguage> enabledLanguages,
  ) {
    final rawMap = raw is Map ? raw : <String, dynamic>{};
    final result = <SupportedLanguage, String>{};

    // Safe retrieval with fallback to English or the first available value
    String getFallback() {
      if (rawMap.containsKey('en')) return rawMap['en'].toString();
      if (rawMap.isNotEmpty) return rawMap.values.first.toString();
      return '...';
    }

    for (final lang in enabledLanguages) {
      final key = lang.name;
      if (rawMap.containsKey(key)) {
        result[lang] = rawMap[key].toString();
      } else {
        // Backfill missing enabled language with fallback
        result[lang] = getFallback();
      }
    }
    return result;
  }
}
