/// {@template intelligence_client}
/// An abstract interface for AI providers, enabling the Intelligence Service
/// to be vendor-agnostic.
/// {@endtemplate}
abstract class IntelligenceClient {
  /// Generates a text completion based on a list of messages.
  ///
  /// Returns a record containing the structured response data (as a Map) and
  /// the token usage count.
  Future<({Map<String, dynamic> data, int totalTokens})> generateCompletion({
    required List<Map<String, String>> messages,
    double temperature = 0.1,
    int? maxTokens,
  });
}
