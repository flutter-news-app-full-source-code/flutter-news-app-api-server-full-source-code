import 'dart:convert';

import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:verity_api/src/clients/intelligence/intelligence_client.dart';
import 'package:verity_api/src/config/environment_config.dart';

/// {@template open_router_client}
/// A specialized client for interacting with the OpenRouter.ai API.
/// {@endtemplate}
class OpenRouterClient implements IntelligenceClient {
  /// {@macro open_router_client}
  OpenRouterClient({
    required HttpClient httpClient,
    required Logger log,
  }) : _httpClient = httpClient,
       _log = log;

  final HttpClient _httpClient;
  final Logger _log;

  @override
  Future<({Map<String, dynamic> data, int totalTokens})> generateCompletion({
    required List<Map<String, String>> messages,
    double temperature = 0.1,
    int? maxTokens,
  }) async {
    final apiKey = EnvironmentConfig.aiApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      _log.severe('AI_API_KEY is missing from environment.');
      throw const AuthenticationException('OpenRouter API key is missing.');
    }

    final model = EnvironmentConfig.aiModel;
    _log.info('Dispatching AI request to model: $model');

    try {
      final response = await _httpClient.post<Map<String, dynamic>>(
        'chat/completions',
        data: {
          'model': model,
          'messages': messages,
          'temperature': temperature,
          if (maxTokens != null) 'max_tokens': maxTokens,
          // Force JSON mode for deterministic parsing
          'response_format': {'type': 'json_object'},
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'HTTP-Referer': EnvironmentConfig.apiBaseUrl,
            'X-Title': 'Verity API Ingestion',
          },
        ),
      );

      final choices = response['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        _log.severe('OpenRouter returned an empty choices array.');
        throw const OperationFailedException('AI returned no valid response.');
      }

      final content = choices.first['message']['content'] as String;
      final usage = response['usage'] as Map<String, dynamic>?;
      final totalTokens = (usage?['total_tokens'] as num?)?.toInt() ?? 0;

      _log.fine('AI Request successful. Tokens consumed: $totalTokens');

      return (
        data: _safeJsonParse(content),
        totalTokens: totalTokens,
      );
    } on HttpException catch (e) {
      _log.severe('OpenRouter request failed: ${e.message}');
      // Direct pass-through of standard exceptions
      rethrow;
    } catch (e, s) {
      _log.severe('Unexpected error during AI completion.', e, s);
      throw OperationFailedException('AI provider communication failed: $e');
    }
  }

  Map<String, dynamic> _safeJsonParse(String content) {
    try {
      // The model is forced into JSON mode, but we defensively strip
      // any markdown code block artifacts if they appear.
      final clean = content
          .replaceFirst(RegExp('^```json'), '')
          .replaceFirst(RegExp(r'```$'), '')
          .trim();

      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (e) {
      _log.severe('Failed to parse AI response as JSON: $content');
      throw const OperationFailedException(
        'AI returned malformed JSON data.',
      );
    }
  }
}
