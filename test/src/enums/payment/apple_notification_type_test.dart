import 'package:flutter_news_app_api_server_full_source_code/src/enums/payment/apple_notification_type.dart';
import 'package:test/test.dart';

void main() {
  group('AppleNotificationType', () {
    test('contains expected values', () {
      expect(AppleNotificationType.values, containsAll([
        AppleNotificationType.didRenew,
        AppleNotificationType.subscribed,
        AppleNotificationType.expired,
        AppleNotificationType.didFailToRenew,
        AppleNotificationType.refund,
      ]));
    });
  });
}
