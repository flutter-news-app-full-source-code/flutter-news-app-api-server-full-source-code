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
/// Strategy for enriching a single headline manually via the Admin Dashboard.
///
/// This is used when an admin wants to auto-fill details for a draft or
/// manually created headline. It populates topics, extracts persons, and
/// generates translations.
///
/// This strategy returns a simple DTO, not a persisted entity. The calling
/// service is responsible for resolving the returned slugs and names into
/// full database entities.
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
3. "extractedCountryCodes": A list of 2-letter ISO 3166-1 country codes (e.g. "US", "FR") for countries mentioned in the headline.
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
