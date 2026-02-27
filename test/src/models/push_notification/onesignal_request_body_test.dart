import 'package:core/core.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('OneSignalRequestBody', () {
    const notificationPayload = PushNotificationPayload(
      title: 'Test Title',
      notificationId: 'notif-123',
      notificationType: PushNotificationSubscriptionDeliveryType.breakingOnly,
      contentType: ContentType.headline,
      contentId: 'headline-456',
      imageUrl: 'http://example.com/image.png',
    );

    const oneSignalRequestBody = OneSignalRequestBody(
      appId: 'test-app-id',
      includePlayerIds: ['player-1', 'player-2'],
      headings: {'en': 'Test Title'},
      data: notificationPayload,
      bigPicture: 'http://example.com/image.png',
    );

    test('can be instantiated', () {
      expect(oneSignalRequestBody, isNotNull);
    });

    test('supports value equality', () {
      expect(
        oneSignalRequestBody,
        equals(
          const OneSignalRequestBody(
            appId: 'test-app-id',
            includePlayerIds: ['player-1', 'player-2'],
            headings: {'en': 'Test Title'},
            data: notificationPayload,
            bigPicture: 'http://example.com/image.png',
          ),
        ),
      );
    });

    test('props are correct', () {
      expect(
        oneSignalRequestBody.props,
        equals(<Object?>[
          'test-app-id',
          ['player-1', 'player-2'],
          {'en': 'Test Title'},
          null, // contents
          notificationPayload,
          'http://example.com/image.png',
        ]),
      );
    });

    group('toJson', () {
      test('works correctly with all fields', () {
        expect(
          oneSignalRequestBody.toJson(),
          equals(<String, dynamic>{
            'app_id': 'test-app-id',
            'include_player_ids': ['player-1', 'player-2'],
            'headings': {'en': 'Test Title'},
            'data': {
              'title': 'Test Title',
              'notificationId': 'notif-123',
              'notificationType': 'breakingOnly',
              'contentType': 'headline',
              'contentId': 'headline-456',
              'imageUrl': 'http://example.com/image.png',
            },
            'big_picture': 'http://example.com/image.png',
          }),
        );
      });

      test('omits null fields', () {
        const payloadWithoutImage = PushNotificationPayload(
          title: 'Test Title',
          notificationId: 'notif-123',
          notificationType:
              PushNotificationSubscriptionDeliveryType.breakingOnly,
          contentType: ContentType.headline,
          contentId: 'headline-456',
        );
        const bodyWithoutImage = OneSignalRequestBody(
          appId: 'test-app-id',
          includePlayerIds: ['player-1'],
          headings: {'en': 'Test Title'},
          data: payloadWithoutImage,
        );

        expect(
          bodyWithoutImage.toJson(),
          equals(<String, dynamic>{
            'app_id': 'test-app-id',
            'include_player_ids': ['player-1'],
            'headings': {'en': 'Test Title'},
            'data': {
              'title': 'Test Title',
              'notificationId': 'notif-123',
              'notificationType': 'breakingOnly',
              'contentType': 'headline',
              'contentId': 'headline-456',
              'imageUrl': null,
            },
          }),
        );
      });
    });
  });
}
