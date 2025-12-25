import 'package:flutter_news_app_api_server_full_source_code/src/enums/payment/google_notification_type.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/google_subscription_notification.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSubscriptionNotification', () {
    const notification = GoogleSubscriptionNotification(
      version: '1.0',
      packageName: 'com.example',
      eventTimeMillis: '1678886400000',
      subscriptionNotification: GoogleSubscriptionDetails(
        version: '1.0',
        notificationType: GoogleNotificationType.subscriptionRenewed,
        purchaseToken: 'token-123',
        subscriptionId: 'sub-1',
      ),
    );

    test('supports value equality', () {
      const notification2 = GoogleSubscriptionNotification(
        version: '1.0',
        packageName: 'com.example',
        eventTimeMillis: '1678886400000',
        subscriptionNotification: GoogleSubscriptionDetails(
          version: '1.0',
          notificationType: GoogleNotificationType.subscriptionRenewed,
          purchaseToken: 'token-123',
          subscriptionId: 'sub-1',
        ),
      );
      expect(notification, equals(notification2));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'version': '1.0',
        'packageName': 'com.example',
        'eventTimeMillis': '1678886400000',
        'subscriptionNotification': {
          'version': '1.0',
          'notificationType': 2,
          'purchaseToken': 'token-123',
          'subscriptionId': 'sub-1',
        },
        'testNotification': null,
      };
      expect(GoogleSubscriptionNotification.fromJson(json), equals(notification));
    });

    test('toJson serializes correctly', () {
      final json = notification.toJson();
      expect(json['version'], '1.0');
      expect(json['subscriptionNotification']['notificationType'], 2);
    });
  });
}
