import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/app_store_server_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/apple_subscription_response.dart';
import 'package:http_client/http_client.dart';
import 'package:jose/jose.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockLogger extends Mock implements Logger {}

void main() {
  group('AppStoreServerClient', () {
    late HttpClient mockHttpClient;
    late Logger mockLogger;
    late AppStoreServerClient client;

    const originalTransactionId = 'test-transaction-id';

    setUpAll(() {
      registerFallbackValue(Options(headers: {}));
    });

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockLogger = MockLogger();

      // Set up mock environment variables
      EnvironmentConfig.appleAppStoreIssuerId = 'issuer-id';
      EnvironmentConfig.appleAppStoreKeyId = 'key-id';
      EnvironmentConfig.appleBundleId = 'bundle-id';
      // A valid PEM-formatted EC private key for testing JWT generation
      EnvironmentConfig.appleAppStorePrivateKey = '''
-----BEGIN PRIVATE KEY-----
MEECAQAwEwYHKoZIzj0CAQYIKoZIzj0DAQcEJzAlAgEBBCCD0a3d7Vd2zV/i4sGD
g3s2+a0y9aYj4xJj4m2n2aXy/A==
-----END PRIVATE KEY-----
''';

      client = AppStoreServerClient(
        log: mockLogger,
        httpClient: mockHttpClient,
      );
    });

    group('getAllSubscriptionStatuses', () {
      test('succeeds and returns parsed response', () async {
        final responseJson = {
          'environment': 'Sandbox',
          'bundleId': 'bundle-id',
          'data': <dynamic>[],
        };
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) async => responseJson);

        final response = await client.getAllSubscriptionStatuses(
          originalTransactionId,
        );

        expect(response, isA<AppleSubscriptionResponse>());
        final captured = verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
            captureAny(),
            options: captureAny(named: 'options'),
          ),
        ).captured;

        expect(
          captured[0],
          '/subscriptions/$originalTransactionId',
        );
        final options = captured[1] as Options;
        expect(options.headers?['Authorization'], startsWith('Bearer ey'));
      });

      test('rethrows NotFoundException on 404', () async {
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenThrow(const NotFoundException('Not Found'));

        expect(
          () => client.getAllSubscriptionStatuses(originalTransactionId),
          throwsA(isA<NotFoundException>()),
        );
      });

      test('throws ServerException on other errors', () async {
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenThrow(Exception('Unexpected error'));

        expect(
          () => client.getAllSubscriptionStatuses(originalTransactionId),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('decodeTransaction', () {
      test('correctly decodes a valid JWS payload', () {
        // Create a simple, unsecured JWS for testing the decoding logic.
        final claims = JsonWebTokenClaims.fromJson({
          'originalTransactionId': 'orig-123',
          'transactionId': 'trans-123',
          'productId': 'prod-1',
          'purchaseDate': 1678886400000,
          'originalPurchaseDate': 1678886400000,
          'expiresDate': 1678886400000,
          'type': 'Auto-Renewable Subscription',
          'inAppOwnershipType': 'PURCHASED',
        });
        final jwsString =
            'eyJhbGciOiJub25lIn0.${base64Url.encode(utf8.encode(json.encode(claims.toJson())))}.';

        final decodedPayload = client.decodeTransaction(jwsString);

        expect(decodedPayload.originalTransactionId, 'orig-123');
        expect(decodedPayload.productId, 'prod-1');
      });
    });
  });
}
