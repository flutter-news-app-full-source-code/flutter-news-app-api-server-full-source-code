import 'package:core/core.dart';
import 'package:verity_api/src/services/intelligence/strategies/ai_strategy.dart';
import 'package:verity_api/src/utils/localization_utils.dart';

/// {@template single_enrichment_strategy}
/// Strategy for enriching a single headline manually via the Admin Dashboard.
///
/// This is used when an admin wants to auto-fill details for a draft or
/// manually created headline. It populates topics, extracts persons, and
/// generates translations.
/// {@endtemplate}
class SingleEnrichmentStrategy extends AiStrategy<Headline, Headline> {
  @override
  String get identifier => 'single_enrichment';

  @override
  List<Map<String, String>> buildPrompt(
    Headline input, {
    required List<SupportedLanguage> enabledLanguages,
  }) {
    final languages = enabledLanguages.map((e) => e.name).join(', ');

    return [
      {
        'role': 'system',
        'content':
            '''
You are an expert news editor. Analyze the given headline and return a valid JSON object with the following fields:
1. "topicId": Infer the most relevant topic ID from the context.
2. "extractedPersons": A list of full names of public figures mentioned.
3. "translations": A dictionary where keys are language codes ($languages) and values are the translated title.
''',
      },
      {
        'role': 'user',
        'content': 'Title: ${input.title.values.first}. URL: ${input.url}',
      },
    ];
  }

  @override
  Headline mapResponse(Map<String, dynamic> data, Headline input) {
    // 1. Parse Translations
    final rawTranslations = data['translations'] as Map<String, dynamic>? ?? {};
    final translations = <SupportedLanguage, String>{};

    for (final entry in rawTranslations.entries) {
      try {
        final lang = SupportedLanguage.values.byName(entry.key);
        translations[lang] = entry.value as String;
      } catch (_) {
        // Ignore unsupported languages returned by AI hallucination
      }
    }

    // Merge with existing title to ensure original is preserved if needed,
    // though typically the AI should provide the full set.
    final updatedTitle = LocalizationUtils.mergeTranslations(
      input.title,
      translations,
    );

    // 2. Parse Topic
    // Note: In a real app, we might want to validate this ID against the DB.
    // Here we assume the AI (if fine-tuned or prompted with valid IDs) returns
    // a plausible string, or we rely on the admin to verify before saving.
    final topicId = data['topicId'] as String?;
    final updatedTopic = topicId != null
        ? input.topic.copyWith(id: topicId)
        : input.topic;

    // 3. Parse Persons
    // The IdentityResolutionService is NOT called here because this strategy
    // returns a non-persisted object to the Admin UI. The Admin will verify
    // and save, triggering identity resolution/linking at the repository level
    // or via a subsequent call if needed. For now, we populate the
    // names into temporary Person objects.
    final rawNames = List<String>.from(data['extractedPersons'] ?? []);
    final tempPersons = rawNames.map((name) {
      // We use a placeholder ID as these are not yet DB entities.
      return Person(
        id: '',
        name: {SupportedLanguage.en: name},
        description: const {},
      );
    }).toList();

    return input.copyWith(
      title: updatedTitle,
      topic: updatedTopic,
      mentionedPersons: tempPersons,
    );
  }
}
