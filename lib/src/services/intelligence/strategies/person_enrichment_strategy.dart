import 'package:core/core.dart';
import 'package:veritai_api/src/services/intelligence/strategies/ai_strategy.dart';

typedef PersonEnrichmentResult = ({
  Map<SupportedLanguage, String> name,
  Map<SupportedLanguage, String> description,
});

class PersonEnrichmentStrategy
    extends AiStrategy<Person, PersonEnrichmentResult> {
  @override
  String get identifier => 'person_enrichment';

  @override
  List<Map<String, String>> buildPrompt(
    Person input, {
    required List<SupportedLanguage> enabledLanguages,
    List<String> predefinedChoices = const [],
  }) {
    final languages = enabledLanguages.map((e) => e.name).join(', ');

    return [
      {
        'role': 'system',
        'content':
            '''
You are an expert biographer. Your task is to enrich a Person (public figure) entity and return a single, valid JSON object with the following strict schema:

1. `name` (object): A dictionary mapping language codes to the person's FULL NAME in these languages: [$languages].
2. `description` (object): A dictionary mapping language codes to a brief, professional description of the person's role or significance in these languages: [$languages].

Return ONLY the valid JSON object. Do not include any other text, explanations, or markdown.
''',
      },
      {
        'role': 'user',
        'content': 'Person Data: ${input.toJson()}',
      },
    ];
  }

  @override
  PersonEnrichmentResult mapResponse(
    Map<String, dynamic> data,
    Person input,
    List<SupportedLanguage> enabledLanguages,
  ) {
    return (
      name: _parseGenericTranslations(data['name'], enabledLanguages),
      description: _parseGenericTranslations(
        data['description'],
        enabledLanguages,
      ),
    );
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
