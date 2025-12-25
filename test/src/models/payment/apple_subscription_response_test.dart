import 'package:flutter_news_app_api_server_full_source_code/src/enums/payment/apple_environment.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/apple_subscription_response.dart';
import 'package:test/test.dart';

void main() {
  group('AppleSubscriptionResponse', () {
    const response = AppleSubscriptionResponse(
      environment: AppleEnvironment.production,
      bundleId: 'com.example',
      data: [
        AppleSubscriptionGroupItem(
          subscriptionGroupIdentifier: 'group-1',
          lastTransactions: [
            AppleLastTransactionItem(
              originalTransactionId: 'orig-1',
              status: 1,
              signedRenewalInfo: 'renew-1',
              signedTransactionInfo: 'trans-1',
            ),
          ],
        ),
      ],
    );

    test('supports value equality', () {
      const response2 = AppleSubscriptionResponse(
        environment: AppleEnvironment.production,
        bundleId: 'com.example',
        data: [
          AppleSubscriptionGroupItem(
            subscriptionGroupIdentifier: 'group-1',
            lastTransactions: [
              AppleLastTransactionItem(
                originalTransactionId: 'orig-1',
                status: 1,
                signedRenewalInfo: 'renew-1',
                signedTransactionInfo: 'trans-1',
              ),
            ],
          ),
        ],
      );
      expect(response, equals(response2));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'environment': 'Production',
        'bundleId': 'com.example',
        'data': [
          {
            'subscriptionGroupIdentifier': 'group-1',
            'lastTransactions': [
              {
                'originalTransactionId': 'orig-1',
                'status': 1,
                'signedRenewalInfo': 'renew-1',
                'signedTransactionInfo': 'trans-1',
              },
            ],
          },
        ],
      };
      expect(AppleSubscriptionResponse.fromJson(json), equals(response));
    });

    test('toJson serializes correctly', () {
      final json = response.toJson();
      expect(json['environment'], 'Production');
      expect(json['bundleId'], 'com.example');
      expect(
        (json['data'] as List).first['subscriptionGroupIdentifier'],
        'group-1',
      );
    });
  });
}
