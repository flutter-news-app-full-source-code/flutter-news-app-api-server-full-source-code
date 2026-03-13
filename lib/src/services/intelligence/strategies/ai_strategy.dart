import 'package:core/core.dart';

/// {@template ai_strategy}
/// Base contract for AI decision-making logic.
///
/// Strategies define how to construct prompts and how to map the raw
/// AI response back into domain-specific objects.
/// {@endtemplate}
abstract class AiStrategy<TInput, TOutput> {
  /// The primary identifier for this strategy (e.g., 'ingestion').
  String get identifier;

  /// Constructs the messages array for the LLM.
  List<Map<String, String>> buildPrompt(
    TInput input, {
    required List<SupportedLanguage> enabledLanguages,
    List<String> predefinedChoices = const [],
  });

  /// Maps the raw JSON response from the LLM to the expected domain output.
  TOutput mapResponse(
    Map<String, dynamic> data,
    TInput input,
    List<SupportedLanguage> enabledLanguages,
  );
}
