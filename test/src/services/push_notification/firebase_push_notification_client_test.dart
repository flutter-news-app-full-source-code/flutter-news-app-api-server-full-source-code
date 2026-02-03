import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/push_notification/firebase_push_notification_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/push_notification/push_notification_client.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockDataRepository<T> extends Mock implements DataRepository<T> {}

class MockIPushNotificationClient extends Mock
    implements IPushNotificationClient {}

class MockHttpClient extends Mock implements HttpClient {}

class MockLogger extends Mock implements Logger {}

void main() {
  group('FirebasePushNotificationClient', () {
    setUpAll(() {
      registerFallbackValue(StackTrace.empty);
    });

    late HttpClient httpClient;
    late Logger logger;
    late FirebasePushNotificationClient client;

    const projectId = 'test-project';
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
      client = FirebasePushNotificationClient(
        projectId: projectId,
        httpClient: httpClient,
        log: logger,
      );

      // Mute the logger during tests
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
          () => httpClient.post<void>(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        );
      });

      test('sends a single notification successfully', () async {
        const token = 'token1';
        when(
          () => httpClient.post<void>(
            'messages:send',
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async {});

        final result = await client.sendBulkNotifications(
          deviceTokens: [token],
          payload: payload,
        );

        expect(result.sentTokens, [token]);
        expect(result.failedTokens, isEmpty);

        final captured =
            verify(
                  () => httpClient.post<void>(
                    'messages:send',
                    data: captureAny<Map<String, dynamic>>(named: 'data'),
                  ),
                ).captured.first
                as Map<String, dynamic>;

        expect(captured['message']['token'], token);
      });

      test('handles NotFoundException and marks token as failed', () async {
        const validToken = 'valid-token';
        const invalidToken = 'invalid-token';

        when(
          () => httpClient.post<void>(
            'messages:send',
            data: any<Map<String, dynamic>>(
              named: 'data',
              that: predicate<Map<String, dynamic>>(
                (d) => d['message']['token'] == validToken,
              ),
            ),
          ),
        ).thenAnswer((_) async {});

        when(
          () => httpClient.post<void>(
            'messages:send',
            data: any<Map<String, dynamic>>(
              named: 'data',
              that: predicate<Map<String, dynamic>>(
                (d) => d['message']['token'] == invalidToken,
              ),
            ),
          ),
        ).thenAnswer(
          (_) => Future.error(const NotFoundException('unregistered')),
        );

        final result = await client.sendBulkNotifications(
          deviceTokens: [validToken, invalidToken],
          payload: payload,
        );

        expect(result.sentTokens, [validToken]);
        expect(result.failedTokens, [invalidToken]);
      });

      test(
        'handles other HttpExceptions and does not mark token as failed',
        () async {
          const token = 'token1';
          when(
            () => httpClient.post<void>(
              'messages:send',
              data: any<dynamic>(named: 'data'),
            ),
          ).thenAnswer(
            (_) => Future.error(const ServerException('server unavailable')),
          );

          final result = await client.sendBulkNotifications(
            deviceTokens: [token],
            payload: payload,
          );

          expect(result.sentTokens, isEmpty);
          expect(result.failedTokens, isEmpty);
          verify(
            () => logger.severe(
              any(that: contains('HTTP error')),
              any<dynamic>(),
              any<StackTrace>(),
            ),
          ).called(1);
        },
      );
    });
  });
}
