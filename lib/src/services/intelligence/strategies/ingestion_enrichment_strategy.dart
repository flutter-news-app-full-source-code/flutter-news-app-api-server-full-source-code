import 'package:core/core.dart';
import 'package:verity_api/src/services/intelligence/strategies/ai_strategy.dart';

/// Result of the AI processing for a single headline in a batch.
typedef AiEnrichmentResult = ({
  bool isNews,
  String? topicId,
  List<String> extractedPersons,
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
  }) {
    final languages = enabledLanguages.map((e) => e.name).join(', ');

    // We send a minimal representation to save input tokens.
    final items = input
        .map(
          (h) => {
            'id': h.id,
            'title': h.title.values.first,
            'url': h.url,
          },
        )
        .toList();

    return [
      {
        'role': 'system',
        'content':
            '''
You are an expert news analyst and translator. 
Analyze the provided headlines and return a JSON object where the keys are 
the headline IDs. For each headline:
1. "isNews": Boolean. False if it is an ad, weather report, help page, or junk.
2. "topicId": Infer the most relevant topic ID from the context if possible.
3. "extractedPersons": A list of full names of public figures mentioned.
4. "breakingConfidence": A float (0.0-1.0) indicating if this is urgent news.
5. "translations": Translate the title into these languages: [$languages].

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
    List<Headline> input,
  ) {
    final results = <String, AiEnrichmentResult>{};

    for (final entry in data.entries) {
      final id = entry.key;
      final val = entry.value as Map<String, dynamic>;

      results[id] = (
        isNews: val['isNews'] as bool? ?? true,
        topicId: val['topicId'] as String?,
        extractedPersons: List<String>.from(val['extractedPersons'] ?? []),
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
