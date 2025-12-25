import 'package:flutter_news_app_api_server_full_source_code/src/enums/payment/apple_notification_subtype.dart';
import 'package:test/test.dart';

void main() {
  group('AppleNotificationSubtype', () {
    test('contains expected values', () {
      expect(
        AppleNotificationSubtype.values,
        containsAll([
          AppleNotificationSubtype.initialBuy,
          AppleNotificationSubtype.resubscribe,
          AppleNotificationSubtype.downgrade,
          AppleNotificationSubtype.upgrade,
          AppleNotificationSubtype.autoRenewEnabled,
          AppleNotificationSubtype.autoRenewDisabled,
        ]),
      );
    });
  });
}
