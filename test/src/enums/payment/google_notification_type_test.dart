import 'package:flutter_news_app_api_server_full_source_code/src/enums/payment/google_notification_type.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleNotificationType', () {
    test('contains expected values', () {
      expect(
        GoogleNotificationType.values,
        containsAll([
          GoogleNotificationType.subscriptionRecovered,
          GoogleNotificationType.subscriptionRenewed,
          GoogleNotificationType.subscriptionCanceled,
          GoogleNotificationType.subscriptionPurchased,
          GoogleNotificationType.subscriptionExpired,
        ]),
      );
    });
  });
}
