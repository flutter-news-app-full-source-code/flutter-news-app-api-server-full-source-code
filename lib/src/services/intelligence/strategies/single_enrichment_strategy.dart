import 'package:core/core.dart';
import 'package:verity_api/src/services/intelligence/strategies/ai_strategy.dart';

/// The result of a single headline enrichment operation.
typedef SingleEnrichmentResult = ({
  String? topicSlug,
  List<String> extractedPersons,
  List<String> extractedCountryCodes,
  Map<SupportedLanguage, String> translations,
});

/// {@template single_enrichment_strategy}
/// A specialized strategy designed to hydrate partial content via the
/// administrative dashboard.
///
/// This strategy accepts a draft headline and performs a comprehensive analysis
/// to generate translations, infer topics, and resolve referenced entities.
///
/// **Data Persistence Strategy:**
/// *   **Dependencies (Persisted):** Referenced public figures are immediately
///     resolved against the `persons` collection. New entities are automatically
///     created and saved to ensure data integrity and linkability.
/// *   **Headline (Ephemeral):** The headline object itself is returned as a
///     transient data transfer object (DTO) and is **not** saved to the
///     database. This allows administrators to review and refine the AI-generated
///     suggestions before committing the final record.
/// {@endtemplate}
class SingleEnrichmentStrategy
    extends AiStrategy<Headline, SingleEnrichmentResult> {
  @override
  String get identifier => 'single_enrichment';

  @override
  List<Map<String, String>> buildPrompt(
    Headline input, {
    required List<SupportedLanguage> enabledLanguages,
    List<String> predefinedChoices = const [],
  }) {
    // We only need to request translations for languages not already present.
    final missingLanguages = enabledLanguages
        .where((lang) => !input.title.containsKey(lang))
        .map((e) => e.name)
        .join(', ');

    return [
      {
        'role': 'system',
        'content':
            '''
You are an expert news editor. Based on the provided headline title, return a valid JSON object with the following fields:
1. "topicSlug": A string. From this exact list, select the single most relevant topic slug: [$predefinedChoices].
2. "extractedPersons": A list of strings, containing the full names of any public figures mentioned.
3. "extractedCountryCodes": A list of 2-letter ISO 3166-1 country codes (e.g. "US", "FR") representing any mentioned countries, or the parent countries of any specific cities, regions, or landmarks found in the headline.
4. "translations": A dictionary translating the title into these languages: [$missingLanguages]. Do NOT include an image URL.

Return ONLY valid JSON. Do not generate fields that were not requested.
''',
      },
      {
        'role': 'user',
        'content': 'Title: ${input.title.values.first}',
      },
    ];
  }

  @override
  SingleEnrichmentResult mapResponse(
    Map<String, dynamic> data,
    Headline input,
  ) {
    final rawTranslations = data['translations'] as Map<String, dynamic>? ?? {};
    final translations = <SupportedLanguage, String>{};
    for (final entry in rawTranslations.entries) {
      try {
        final lang = SupportedLanguage.values.byName(entry.key);
        translations[lang] = entry.value as String;
      } catch (_) {
        // Ignore unsupported languages from AI hallucination
      }
    }

    return (
      topicSlug: data['topicSlug'] as String?,
      extractedPersons: List<String>.from(
        data['extractedPersons'] as List? ?? [],
      ),
      extractedCountryCodes: List<String>.from(
        data['extractedCountryCodes'] as List? ?? [],
      ),
      translations: translations,
    );
  }
}
