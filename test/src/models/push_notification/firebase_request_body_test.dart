import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('FirebaseRequestBody', () {
    const notificationPayload = PushNotificationPayload(
      title: 'Test Title',
      notificationId: 'notif-123',
      notificationType: PushNotificationSubscriptionDeliveryType.breakingOnly,
      contentType: ContentType.headline,
      contentId: 'headline-456',
      imageUrl: 'http://example.com/image.png',
    );

    const firebaseNotification = FirebaseNotification(
      title: 'Test Title',
      image: 'http://example.com/image.png',
    );

    const firebaseMessage = FirebaseMessage(
      token: 'test-token',
      notification: firebaseNotification,
      data: notificationPayload,
    );

    const firebaseRequestBody = FirebaseRequestBody(
      message: firebaseMessage,
    );

    test('can be instantiated', () {
      expect(firebaseRequestBody, isNotNull);
    });

    test('supports value equality', () {
      expect(
        const FirebaseRequestBody(message: firebaseMessage),
        equals(const FirebaseRequestBody(message: firebaseMessage)),
      );
    });

    test('props are correct', () {
      expect(
        const FirebaseRequestBody(message: firebaseMessage).props,
        equals(<Object>[firebaseMessage]),
      );
    });

    group('toJson', () {
      test('works correctly', () {
        expect(
          firebaseRequestBody.toJson(),
          equals(<String, dynamic>{
            'message': {
              'token': 'test-token',
              'notification': {
                'title': 'Test Title',
                'body': null,
                'image': 'http://example.com/image.png',
              },
              'data': {
                'title': 'Test Title',
                'notificationId': 'notif-123',
                'notificationType': 'breakingOnly',
                'contentType': 'headline',
                'contentId': 'headline-456',
                'imageUrl': 'http://example.com/image.png',
              },
            },
          }),
        );
      });

      test('handles null image correctly', () {
        const payloadWithoutImage = PushNotificationPayload(
          title: 'Test Title',
          notificationId: 'notif-123',
          notificationType:
              PushNotificationSubscriptionDeliveryType.breakingOnly,
          contentType: ContentType.headline,
          contentId: 'headline-456',
        );
        const notificationWithoutImage = FirebaseNotification(
          title: 'Test Title',
        );
        const messageWithoutImage = FirebaseMessage(
          token: 'test-token',
          notification: notificationWithoutImage,
          data: payloadWithoutImage,
        );
        const body = FirebaseRequestBody(message: messageWithoutImage);

        expect(
          body.toJson(),
          equals(<String, dynamic>{
            'message': {
              'token': 'test-token',
              'notification': {
                'title': 'Test Title',
                'body': null,
                'image': null,
              },
              'data': {
                'title': 'Test Title',
                'notificationId': 'notif-123',
                'notificationType': 'breakingOnly',
                'contentType': 'headline',
                'contentId': 'headline-456',
                'imageUrl': null,
              },
            },
          }),
        );
      });
    });
  });
}
