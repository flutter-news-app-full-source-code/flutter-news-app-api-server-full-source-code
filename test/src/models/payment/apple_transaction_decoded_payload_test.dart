import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/apple_transaction_decoded_payload.dart';
import 'package:test/test.dart';

void main() {
  group('AppleTransactionDecodedPayload', () {
    final date = DateTime.fromMillisecondsSinceEpoch(1678886400000);
    final payload = AppleTransactionDecodedPayload(
      originalTransactionId: 'orig-123',
      transactionId: 'trans-123',
      productId: 'prod-1',
      purchaseDate: date,
      originalPurchaseDate: date,
      expiresDate: date,
      type: 'Auto-Renewable Subscription',
      inAppOwnershipType: 'PURCHASED',
    );

    test('supports value equality', () {
      final payload2 = AppleTransactionDecodedPayload(
        originalTransactionId: 'orig-123',
        transactionId: 'trans-123',
        productId: 'prod-1',
        purchaseDate: date,
        originalPurchaseDate: date,
        expiresDate: date,
        type: 'Auto-Renewable Subscription',
        inAppOwnershipType: 'PURCHASED',
      );
      expect(payload, equals(payload2));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'originalTransactionId': 'orig-123',
        'transactionId': 'trans-123',
        'productId': 'prod-1',
        'purchaseDate': 1678886400000,
        'originalPurchaseDate': 1678886400000,
        'expiresDate': 1678886400000,
        'type': 'Auto-Renewable Subscription',
        'inAppOwnershipType': 'PURCHASED',
      };
      expect(AppleTransactionDecodedPayload.fromJson(json), equals(payload));
    });

    test('toJson serializes correctly', () {
      final json = payload.toJson();
      expect(json['originalTransactionId'], 'orig-123');
      expect(json['purchaseDate'], 1678886400000);
    });
  });
}
