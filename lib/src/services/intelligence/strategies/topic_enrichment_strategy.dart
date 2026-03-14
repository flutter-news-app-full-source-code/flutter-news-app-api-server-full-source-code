import 'package:core/core.dart';
import 'package:veritai_api/src/services/intelligence/strategies/ai_strategy.dart';

typedef TopicEnrichmentResult = ({
  Map<SupportedLanguage, String> name,
  Map<SupportedLanguage, String> description,
});

class TopicEnrichmentStrategy extends AiStrategy<Topic, TopicEnrichmentResult> {
  @override
  String get identifier => 'topic_enrichment';

  @override
  List<Map<String, String>> buildPrompt(
    Topic input, {
    required List<SupportedLanguage> enabledLanguages,
    List<String> predefinedChoices = const [],
  }) {
    final languages = enabledLanguages.map((e) => e.name).join(', ');

    return [
      {
        'role': 'system',
        'content':
            '''
You are an expert taxonomist. Your task is to enrich a news Topic entity and return a single, valid JSON object with the following strict schema:

1. `name` (object): A dictionary mapping language codes to the topic's FULL NAME in these languages: [$languages].
2. `description` (object): A dictionary mapping language codes to a professional, factual description of the topic in these languages: [$languages].

Return ONLY the valid JSON object. Do not include any other text, explanations, or markdown.
''',
      },
      {
        'role': 'user',
        'content': 'Topic Data: ${input.toJson()}',
      },
    ];
  }

  @override
  TopicEnrichmentResult mapResponse(
    Map<String, dynamic> data,
    Topic input,
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
