import 'package:flutter_news_app_api_server_full_source_code/src/enums/payment/apple_environment.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/payment/apple_notification_subtype.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/payment/apple_notification_type.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/apple_notification_payload.dart';
import 'package:test/test.dart';

void main() {
  group('AppleNotificationPayload', () {
    final date = DateTime.fromMillisecondsSinceEpoch(1678886400000);
    final payload = AppleNotificationPayload(
      notificationType: AppleNotificationType.subscribed,
      subtype: AppleNotificationSubtype.initialBuy,
      notificationUUID: 'uuid-123',
      version: '2.0',
      signedDate: date,
      data: const AppleNotificationData(
        signedTransactionInfo: 'trans-info',
        signedRenewalInfo: 'renew-info',
        bundleId: 'com.example.app',
        bundleVersion: '1.0.0',
        environment: AppleEnvironment.sandbox,
      ),
    );

    test('supports value equality', () {
      final payload2 = AppleNotificationPayload(
        notificationType: AppleNotificationType.subscribed,
        subtype: AppleNotificationSubtype.initialBuy,
        notificationUUID: 'uuid-123',
        version: '2.0',
        signedDate: date,
        data: const AppleNotificationData(
          signedTransactionInfo: 'trans-info',
          signedRenewalInfo: 'renew-info',
          bundleId: 'com.example.app',
          bundleVersion: '1.0.0',
          environment: AppleEnvironment.sandbox,
        ),
      );
      expect(payload, equals(payload2));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'notificationType': 'SUBSCRIBED',
        'subtype': 'INITIAL_BUY',
        'notificationUUID': 'uuid-123',
        'version': '2.0',
        'signedDate': 1678886400000,
        'data': {
          'signedTransactionInfo': 'trans-info',
          'signedRenewalInfo': 'renew-info',
          'bundleId': 'com.example.app',
          'bundleVersion': '1.0.0',
          'environment': 'Sandbox',
        },
      };
      expect(AppleNotificationPayload.fromJson(json), equals(payload));
    });

    test('toJson serializes correctly', () {
      final json = payload.toJson();
      expect(json['notificationType'], 'SUBSCRIBED');
      expect(json['subtype'], 'INITIAL_BUY');
      expect(json['notificationUUID'], 'uuid-123');
      expect(json['signedDate'], 1678886400000);
      expect(json['data']['environment'], 'Sandbox');
    });
  });
}
