import 'package:core/core.dart';
import 'package:veritai_api/src/services/intelligence/strategies/ai_strategy.dart';

/// The result of a source enrichment operation.
typedef SourceEnrichmentResult = ({
  Map<SupportedLanguage, String> name,
  Map<SupportedLanguage, String> description,
  String? headquarters,
  String? sourceType,
  String? primaryLanguage,
  String? url,
});

/// {@template source_enrichment_strategy}
/// A strategy for enriching news source metadata via the AI agent.
/// {@endtemplate}
class SourceEnrichmentStrategy
    extends AiStrategy<Source, SourceEnrichmentResult> {
  @override
  String get identifier => 'source_enrichment';

  @override
  List<Map<String, String>> buildPrompt(
    Source input, {
    required List<SupportedLanguage> enabledLanguages,
    List<String> predefinedChoices = const [],
  }) {
    final languages = enabledLanguages.map((e) => e.name).join(', ');
    final sourceTypes = SourceType.values.map((e) => e.name).join(', ');
    final supportedLangs = SupportedLanguage.values
        .map((e) => e.name)
        .join(', ');

    return [
      {
        'role': 'system',
        'content':
            '''
You are an expert metadata researcher. Your task is to enrich a news Source entity and return a single, valid JSON object with the following strict schema:

1. `name` (object): A dictionary mapping language codes to the source's FULL NAME in these languages: [$languages].
2. `description` (object): A dictionary mapping language codes to a professional, factual description of the source in these languages: [$languages].
3. `headquarters` (string | null): The 2-letter ISO 3166-1 country code of the country of ownership or editorial origin, or null if unknown.
4. `sourceType` (string): Categorize the source using EXACTLY one of these values: [$sourceTypes].
5. `primaryLanguage` (string): The primary language of the source's content using EXACTLY one of these values: [$supportedLangs].
6. `url` (string): The canonical, base homepage URL of the news source (e.g., "https://www.nytimes.com").

Return ONLY the valid JSON object. Do not include any other text, explanations, or markdown.
''',
      },
      {
        'role': 'user',
        'content': 'Source Data: ${input.toJson()}',
      },
    ];
  }

  @override
  SourceEnrichmentResult mapResponse(
    Map<String, dynamic> data,
    Source input,
    List<SupportedLanguage> enabledLanguages,
  ) {
    return (
      name: _parseGenericTranslations(data['name'], enabledLanguages),
      description: _parseGenericTranslations(
        data['description'],
        enabledLanguages,
      ),
      headquarters: data['headquarters'] as String?,
      sourceType: data['sourceType'] as String?,
      primaryLanguage: data['primaryLanguage'] as String?,
      url: data['url'] as String?,
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
