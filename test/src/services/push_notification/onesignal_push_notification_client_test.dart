import 'package:core/core.dart';

import 'package:flutter_news_app_api_server_full_source_code/src/services/push_notification/onesignal_push_notification_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/push_notification/push_notification_client.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockDataRepository<T> extends Mock implements DataRepository<T> {}

class MockIPushNotificationClient extends Mock
    implements IPushNotificationClient {}

class MockHttpClient extends Mock implements HttpClient {}

class MockLogger extends Mock implements Logger {}

void main() {
  group('OneSignalPushNotificationClient', () {
    setUpAll(() {
      registerFallbackValue(StackTrace.empty);
    });

    late HttpClient httpClient;
    late Logger logger;
    late OneSignalPushNotificationClient client;

    const appId = 'test-app-id';
    const payload = PushNotificationPayload(
      title: 'Test',
      notificationId: 'id',
      notificationType: PushNotificationSubscriptionDeliveryType.breakingOnly,
      contentType: ContentType.headline,
      contentId: 'content-id',
    );

    setUp(() {
      httpClient = MockHttpClient();
      logger = MockLogger();
      client = OneSignalPushNotificationClient(
        appId: appId,
        httpClient: httpClient,
        log: logger,
      );

      when(() => logger.info(any(), any(), any())).thenReturn(null);
      when(() => logger.finer(any(), any(), any())).thenReturn(null);
      when(() => logger.severe(any(), any(), any())).thenReturn(null);
    });

    test('can be instantiated', () {
      expect(client, isNotNull);
    });

    group('sendBulkNotifications', () {
      test('aborts if no device tokens are provided', () async {
        final result = await client.sendBulkNotifications(
          deviceTokens: [],
          payload: payload,
        );
        expect(result.sentTokens, isEmpty);
        expect(result.failedTokens, isEmpty);
        verify(
          () => logger.info(
            any(that: contains('No device tokens')),
          ),
        ).called(1);
        verifyNever(
          () => httpClient.post<Map<String, dynamic>>(
            any<String>(),
            data: any<dynamic>(
              named: 'data',
            ),
          ),
        );
      });

      test('sends a single batch successfully', () async {
        const tokens = ['token1', 'token2'];
        when(
          () => httpClient.post<Map<String, dynamic>>(
            'notifications',
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async => <String, dynamic>{'id': 'notif-id'});

        final result = await client.sendBulkNotifications(
          deviceTokens: tokens,
          payload: payload,
        );

        expect(result.sentTokens, orderedEquals(tokens));
        expect(result.failedTokens, isEmpty);

        final captured =
            verify(
                  () => httpClient.post<Map<String, dynamic>>(
                    'notifications',
                    data: captureAny<Map<String, dynamic>>(named: 'data'),
                  ),
                ).captured.first
                as Map<String, dynamic>;

        expect(captured['app_id'], appId);
        expect(captured['include_player_ids'], tokens);
      });

      test('handles invalid_player_ids in response', () async {
        const validTokens = ['valid1', 'valid2'];
        const invalidTokens = ['invalid1'];
        final allTokens = [...validTokens, ...invalidTokens];

        when(
          () => httpClient.post<Map<String, dynamic>>(
            'notifications',
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => <String, dynamic>{
            'id': 'notif-id',
            'errors': {
              'invalid_player_ids': invalidTokens,
            },
          },
        );

        final result = await client.sendBulkNotifications(
          deviceTokens: allTokens,
          payload: payload,
        );

        expect(result.sentTokens, orderedEquals(validTokens));
        expect(result.failedTokens, orderedEquals(invalidTokens));
      });

      test('handles HttpException and marks all tokens as failed', () async {
        const tokens = ['token1', 'token2'];
        when(
          () => httpClient.post<Map<String, dynamic>>(
            'notifications',
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer(
          (_) => Future.error(const ServerException('server unavailable')),
        );

        final result = await client.sendBulkNotifications(
          deviceTokens: tokens,
          payload: payload,
        );

        expect(result.sentTokens, isEmpty);
        expect(result.failedTokens, orderedEquals(tokens));
        verify(
          () => logger.severe(
            any(that: contains('HTTP error')),
            any<dynamic>(),
            any<StackTrace>(),
          ),
        ).called(1);
      });
    });
  });
}
