import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/reward/admob_reward_callback.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/reward/admob_ssv_verifier.dart';
import 'package:http_client/http_client.dart';
import 'package:jose/jose.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements HttpClient {}

void main() {
  group('AdMobSsvVerifier', () {
    late AdMobSsvVerifier verifier;
    late MockHttpClient mockHttpClient;
    late JsonWebKey privateKey;

    // Hardcoded EC P-256 Key Pair for testing.
    // These keys are mathematically consistent.
    const testPrivateKeyJwk = {
      'kty': 'EC',
      'crv': 'P-256',
      'd': '870MB6gfuTJ4HtUnUvYMyJpr5eUZNP4Bk43bVdj3eAE',
      'x': 'MKBCTNIcKUSDii11ySs3526iDZ8AiTo7Tu6KPAqv7D4',
      'y': '4Etl6SRW2YiLUrN5vfvVHuhp7x8PxltmWWlbbM4IFyM',
      'use': 'sig',
      'alg': 'ES256',
      'kid': 'test-key-id',
    };

    // Corresponding Public Key in PEM format.
    // Constructed from the X and Y coordinates above.
    const testPublicKeyPem = '''
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEMKBCTNIcKUSDii11ySs3526iDZ8A
iTo7Tu6KPAqv7D7gS2XpJFbZiItSs3m9+9Ue6GnvHw/GW2ZZaVtszggXIw==
-----END PUBLIC KEY-----
''';

    setUpAll(() {
      privateKey = JsonWebKey.fromJson(testPrivateKeyJwk);
    });

    setUp(() {
      mockHttpClient = MockHttpClient();
      verifier = AdMobSsvVerifier(
        httpClient: mockHttpClient,
        log: Logger('TestVerifier'),
      );
    });

    String signContent(String content) {
      final signature = privateKey.sign(
        utf8.encode(content),
        algorithm: 'ES256',
      );
      // Encode to URL-safe Base64
      return base64Url.encode(signature).replaceAll('=', '');
    }

    test('verify succeeds with valid signature', () async {
      // 1. Prepare Query
      // We construct the URI first to ensure we sign exactly what the verifier sees
      // after Uri.parse normalization.
      final baseUri = Uri.parse(
        'https://example.com/webhook?ad_network=5450213213286189855&ad_unit=1234567890&reward_amount=1&timestamp=150777823&transaction_id=1234567890&user_id=user123&custom_data=adFree',
      );

      // Extract the query string that AdMob would sign (everything except signature and key_id)
      final contentToSign = baseUri.query;
      final signature = signContent(contentToSign);

      final fullUri = Uri.parse(
        '$baseUri&key_id=test-key-id&signature=$signature',
      );

      final callback = AdMobRewardCallback.fromUri(fullUri);

      // 2. Mock Keys Response
      when(
        () => mockHttpClient.get<Map<String, dynamic>>(any()),
      ).thenAnswer(
        (_) async => {
          'keys': [
            {'keyId': 'test-key-id', 'pem': testPublicKeyPem},
          ],
        },
      );

      // 3. Execute
      await verifier.verify(callback);
      // If no exception is thrown, test passes.
    });

    test('verify throws InvalidInputException for invalid signature', () async {
      // Use a valid base URI structure to pass fromUri validation
      final baseUri = Uri.parse(
        'https://example.com/webhook?transaction_id=123&user_id=user1&custom_data=adFree',
      );
      final contentToSign = baseUri.query;
      final signature = signContent(contentToSign);

      // Tamper with the content in the final URI
      final tamperedUri = Uri.parse(
        'https://example.com/webhook?transaction_id=999&user_id=user1&custom_data=adFree&key_id=test-key-id&signature=$signature',
      );

      final callback = AdMobRewardCallback.fromUri(tamperedUri);

      when(
        () => mockHttpClient.get<Map<String, dynamic>>(any()),
      ).thenAnswer(
        (_) async => {
          'keys': [
            {'keyId': 'test-key-id', 'pem': testPublicKeyPem},
          ],
        },
      );

      expect(
        () => verifier.verify(callback),
        throwsA(isA<InvalidInputException>()),
      );
    });

    test('verify throws InvalidInputException for unknown key_id', () async {
      final baseUri = Uri.parse(
        'https://example.com/webhook?transaction_id=123&user_id=user1&custom_data=adFree',
      );
      final contentToSign = baseUri.query;
      final signature = signContent(contentToSign);

      final fullUri = Uri.parse(
        '$baseUri&key_id=unknown-key&signature=$signature',
      );

      final callback = AdMobRewardCallback.fromUri(fullUri);

      when(
        () => mockHttpClient.get<Map<String, dynamic>>(any()),
      ).thenAnswer(
        (_) async => {
          'keys': [
            {'keyId': 'test-key-id', 'pem': testPublicKeyPem},
          ],
        },
      );

      expect(
        () => verifier.verify(callback),
        throwsA(isA<InvalidInputException>()),
      );
    });

    test('verify caches keys', () async {
      final baseUri = Uri.parse(
        'https://example.com/webhook?transaction_id=123&user_id=user1&custom_data=adFree',
      );
      final contentToSign = baseUri.query;
      final signature = signContent(contentToSign);

      final fullUri = Uri.parse(
        '$baseUri&key_id=test-key-id&signature=$signature',
      );
      final callback = AdMobRewardCallback.fromUri(fullUri);

      when(
        () => mockHttpClient.get<Map<String, dynamic>>(any()),
      ).thenAnswer(
        (_) async => {
          'keys': [
            {'keyId': 'test-key-id', 'pem': testPublicKeyPem},
          ],
        },
      );

      // First call fetches keys
      await verifier.verify(callback);
      verify(() => mockHttpClient.get<Map<String, dynamic>>(any())).called(1);

      // Second call should use cache
      await verifier.verify(callback);
      verifyNever(() => mockHttpClient.get<Map<String, dynamic>>(any()));
    });
  });
}
