// ignore_for_file: inference_failure_on_function_invocation

import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:verity_api/src/clients/intelligence/open_router_client.dart';
import 'package:verity_api/src/config/environment_config.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockLogger extends Mock implements Logger {}

void main() {
  late OpenRouterClient client;
  late MockHttpClient mockHttpClient;
  late MockLogger mockLogger;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockLogger = MockLogger();
    client = OpenRouterClient(httpClient: mockHttpClient, log: mockLogger);
    EnvironmentConfig.setOverride('AI_API_KEY', 'test-key');
    EnvironmentConfig.setOverride('API_BASE_URL', 'http://test.com');
  });

  group('OpenRouterClient', () {
    test(
      'generateCompletion throws AuthenticationException if key missing',
      () async {
        EnvironmentConfig.setOverride('AI_API_KEY', '');
        expect(
          () => client.generateCompletion(messages: []),
          throwsA(isA<AuthenticationException>()),
        );
      },
    );

    test('generateCompletion sends correct payload and headers', () async {
      when(
        () => mockHttpClient.post<Map<String, dynamic>>(
          any<String>(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => {
          'choices': [
            {
              'message': {'content': '{"test": true}'},
            },
          ],
          'usage': {'total_tokens': 50},
        },
      );

      await client.generateCompletion(
        messages: [
          {'role': 'user', 'content': 'hello'},
        ],
      );

      verify(
        () => mockHttpClient.post<Map<String, dynamic>>(
          'chat/completions',
          data: any<dynamic>(
            named: 'data',
            that: isA<Map<String, dynamic>>()
                .having(
                  (d) => d['response_format'],
                  'response_format',
                  {'type': 'json_object'},
                )
                .having((d) => d['messages'], 'messages', isNotEmpty),
          ),
          options: any(
            named: 'options',
            that: isA<Options>().having(
              (o) => o.headers?['Authorization'],
              'auth header',
              'Bearer test-key',
            ),
          ),
        ),
      ).called(1);
    });

    test('strips markdown code blocks from response', () async {
      when(
        () => mockHttpClient.post<Map<String, dynamic>>(
          any<String>(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => {
          'choices': [
            {
              'message': {
                'content': '```json\n{"clean": true}\n```',
              },
            },
          ],
          'usage': {'total_tokens': 10},
        },
      );

      final result = await client.generateCompletion(messages: []);

      expect(result.data, {'clean': true});
      expect(result.totalTokens, 10);
    });
  });
}
