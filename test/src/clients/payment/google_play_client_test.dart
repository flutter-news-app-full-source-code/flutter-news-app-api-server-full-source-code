import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/google_play_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/google_subscription_purchase.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/google_auth_service.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockGoogleAuthService extends Mock implements IGoogleAuthService {}

class MockHttpClient extends Mock implements HttpClient {}

class MockLogger extends Mock implements Logger {}

void main() {
  group('GooglePlayClient', () {
    late IGoogleAuthService mockAuthService;
    late HttpClient mockHttpClient;
    late Logger mockLogger;
    late GooglePlayClient client;

    const subscriptionId = 'test.subscription.id';
    const purchaseToken = 'test-purchase-token';
    const packageName = 'com.example.app';

    setUp(() {
      mockAuthService = MockGoogleAuthService();
      mockHttpClient = MockHttpClient();
      mockLogger = MockLogger();

      EnvironmentConfig.googlePlayPackageName = packageName;

      client = GooglePlayClient(
        googleAuthService: mockAuthService,
        log: mockLogger,
        httpClient: mockHttpClient,
      );

      when(
        () => mockAuthService.getAccessToken(scope: any(named: 'scope')),
      ).thenAnswer((_) async => 'test-token');
    });

    test('getSubscription succeeds and returns parsed response', () async {
      final responseJson = {
        'expiryTimeMillis': '1678886400000',
        'autoRenewing': true,
        'paymentState': 1,
      };
      when(
        () => mockHttpClient.get<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => responseJson);

      final result = await client.getSubscription(
        subscriptionId: subscriptionId,
        purchaseToken: purchaseToken,
      );

      expect(result, isA<GoogleSubscriptionPurchase>());
      expect(result.autoRenewing, isTrue);

      final capturedUrl =
          verify(
                () => mockHttpClient.get<Map<String, dynamic>>(captureAny()),
              ).captured.first
              as String;

      expect(
        capturedUrl,
        '/applications/$packageName/purchases/subscriptions/$subscriptionId/tokens/$purchaseToken',
      );
    });

    test('throws ServerException if package name is not configured', () {
      EnvironmentConfig.googlePlayPackageName = null;
      // Re-create client to pick up null package name
      client = GooglePlayClient(
        googleAuthService: mockAuthService,
        log: mockLogger,
        httpClient: mockHttpClient,
      );

      expect(
        () => client.getSubscription(
          subscriptionId: subscriptionId,
          purchaseToken: purchaseToken,
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws NotFoundException on 404 from API', () {
      when(
        () => mockHttpClient.get<Map<String, dynamic>>(any()),
      ).thenThrow(const NotFoundException('Not Found'));

      expect(
        () => client.getSubscription(
          subscriptionId: subscriptionId,
          purchaseToken: purchaseToken,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('throws ServerException on 403 Forbidden from API', () {
      when(
        () => mockHttpClient.get<Map<String, dynamic>>(any()),
      ).thenThrow(const ForbiddenException('Forbidden'));

      expect(
        () => client.getSubscription(
          subscriptionId: subscriptionId,
          purchaseToken: purchaseToken,
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test(
      'throws when response is missing required fields (malformed JSON)',
      () {
        // Missing 'expiryTimeMillis' which is required by the model
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(any()),
        ).thenAnswer((_) async => {'autoRenewing': true});

        expect(
          () => client.getSubscription(
            subscriptionId: subscriptionId,
            purchaseToken: purchaseToken,
          ),
          throwsA(anything),
        );
      },
    );
  });
}
