import 'package:core/core.dart';
import 'package:veritai_api/src/services/intelligence/strategies/ai_strategy.dart';

typedef HeadlineEnrichmentResult = ({
  String? topicSlug,
  List<Person> extractedPersons,
  List<String> extractedCountryCodes,
  Map<SupportedLanguage, String> translations,
});

class HeadlineEnrichmentStrategy
    extends AiStrategy<Headline, HeadlineEnrichmentResult> {
  @override
  String get identifier => 'headline_enrichment';

  @override
  List<Map<String, String>> buildPrompt(
    Headline input, {
    required List<SupportedLanguage> enabledLanguages,
    List<String> predefinedChoices = const [],
  }) {
    final missingLanguages = enabledLanguages
        .where((lang) => !input.title.containsKey(lang))
        .map((e) => e.name)
        .join(', ');

    return [
      {
        'role': 'system',
        'content':
            '''
You are an expert news editor. Your task is to analyze the provided headline and return a single, valid JSON object with the following strict schema:

1. `topicSlug` (string | null): The single most relevant topic slug from this list: [$predefinedChoices]. You MUST NOT invent slugs. If no topic matches, return `null`.
2. `extractedPersons` (array of objects): An array of all public figures mentioned. Each object MUST have:
   - `name` (object): A dictionary mapping language codes to the person's FULL NAME in these languages: [$missingLanguages].
   - `description` (object): A dictionary mapping language codes to a brief, factual description of the person's role (e.g., "CEO of X"). If unknown, use "...". Required languages: [$missingLanguages].
3. `extractedCountryCodes` (array of strings): A list of 2-letter ISO 3166-1 country codes (e.g., "US", "FR") for any mentioned countries.
4. `translations` (object): A dictionary translating the original headline title into these languages: [$missingLanguages].

Return ONLY the valid JSON object. Do not include any other text, explanations, or markdown.
''',
      },
      {
        'role': 'user',
        'content': 'Title: ${input.title.values.first}',
      },
    ];
  }

  @override
  HeadlineEnrichmentResult mapResponse(
    Map<String, dynamic> data,
    Headline input,
    List<SupportedLanguage> enabledLanguages,
  ) {
    final rawTranslations = data['translations'] as Map<String, dynamic>? ?? {};
    final translations = <SupportedLanguage, String>{};
    for (final entry in rawTranslations.entries) {
      try {
        final lang = SupportedLanguage.values.byName(entry.key);
        translations[lang] = entry.value as String;
      } catch (_) {}
    }

    return (
      topicSlug: data['topicSlug'] as String?,
      extractedPersons: _parsePersons(
        data['extractedPersons'] as List? ?? [],
        enabledLanguages,
      ),
      extractedCountryCodes: List<String>.from(
        data['extractedCountryCodes'] as List? ?? [],
      ),
      translations: translations,
    );
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

    String getFallback() {
      if (rawMap.containsKey('en')) return rawMap['en'].toString();
      if (rawMap.isNotEmpty) return rawMap.values.first.toString();
      return '...';
    }

    for (final lang in enabledLanguages) {
      if (rawMap.containsKey(lang.name)) {
        result[lang] = rawMap[lang.name].toString();
      } else {
        result[lang] = getFallback();
      }
    }
    return result;
  }
}
