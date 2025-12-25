import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/google_subscription_purchase.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSubscriptionPurchase', () {
    const purchase = GoogleSubscriptionPurchase(
      expiryTimeMillis: '1678886400000',
      autoRenewing: true,
      paymentState: 1,
    );

    test('supports value equality', () {
      const purchase2 = GoogleSubscriptionPurchase(
        expiryTimeMillis: '1678886400000',
        autoRenewing: true,
        paymentState: 1,
      );
      expect(purchase, equals(purchase2));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'expiryTimeMillis': '1678886400000',
        'autoRenewing': true,
        'paymentState': 1,
      };
      expect(GoogleSubscriptionPurchase.fromJson(json), equals(purchase));
    });

    test('toJson serializes correctly', () {
      final json = purchase.toJson();
      expect(json['expiryTimeMillis'], '1678886400000');
      expect(json['autoRenewing'], true);
      expect(json['paymentState'], 1);
    });
  });
}
