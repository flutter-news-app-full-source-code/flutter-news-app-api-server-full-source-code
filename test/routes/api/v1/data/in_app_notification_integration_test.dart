import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../src/helpers/test_helpers.dart';
import 'test_api.dart';

void main() {
  group('InAppNotification Integration Tests', () {
    late TestApi api;
    late MockDataRepository<InAppNotification> mockRepo;
    late MockAuthTokenService mockAuthTokenService;

    late User standardUser;
    late User otherUser;
    late String standardToken;
    late String otherUserToken;

    late InAppNotification notification;

    setUpAll(() {
      registerSharedFallbackValues();
      registerFallbackValue(const PaginationOptions());
      registerFallbackValue(const SortOption('createdAt'));
      registerFallbackValue(
        InAppNotification(
          id: 'fallback-id',
          userId: 'fallback-user-id',
          payload: const PushNotificationPayload(
            title: 'Fallback',
            notificationId: 'n1',
            notificationType:
                PushNotificationSubscriptionDeliveryType.breakingOnly,
            contentType: ContentType.headline,
            contentId: 'h1',
          ),
          createdAt: DateTime.now(),
        ),
      );
    });

    setUp(() {
      mockRepo = MockDataRepository<InAppNotification>();
      mockAuthTokenService = MockAuthTokenService();

      standardUser = createTestUser(
        id: 'standard-id',
        email: 'standard@test.com',
      );
      otherUser = createTestUser(
        id: 'other-id',
        email: 'other@test.com',
      );

      standardToken = 'standard-token';
      otherUserToken = 'other-user-token';

      when(
        () => mockAuthTokenService.validateToken(standardToken),
      ).thenAnswer((_) async => standardUser);
      when(
        () => mockAuthTokenService.validateToken(otherUserToken),
      ).thenAnswer((_) async => otherUser);

      notification = InAppNotification(
        id: 'notif-1',
        userId: standardUser.id,
        payload: const PushNotificationPayload(
          title: 'Test',
          notificationId: 'n1',
          notificationType:
              PushNotificationSubscriptionDeliveryType.breakingOnly,
          contentType: ContentType.headline,
          contentId: 'h1',
        ),
        createdAt: DateTime.now(),
      );

      api = TestApi.from(
        (context) => context
            .provide<DataRepository<InAppNotification>>(() => mockRepo)
            .provide<AuthTokenService>(() => mockAuthTokenService),
      );
    });

    group('GET /api/v1/data?model=in_app_notification', () {
      test('returns 200 for owner', () async {
        when(
          () => mockRepo.readAll(
            userId: standardUser.id, // Scoped to user
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [notification],
            cursor: null,
            hasMore: false,
          ),
        );

        final response = await api.get(
          '/api/v1/data?model=in_app_notification',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(await response.body());
        expect(body['data']['items'], hasLength(1));
      });
    });

    group('GET /api/v1/data/:id?model=in_app_notification', () {
      test('returns 200 for owner', () async {
        when(
          () => mockRepo.read(id: notification.id),
        ).thenAnswer((_) async => notification);

        final response = await api.get(
          '/api/v1/data/${notification.id}?model=in_app_notification',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
      });

      test('returns 403 for non-owner', () async {
        when(
          () => mockRepo.read(id: notification.id),
        ).thenAnswer((_) async => notification);

        final response = await api.get(
          '/api/v1/data/${notification.id}?model=in_app_notification',
          headers: {'Authorization': 'Bearer $otherUserToken'},
        );

        expect(response.statusCode, 403);
      });
    });

    group('PUT /api/v1/data/:id?model=in_app_notification', () {
      setUp(() {
        when(
          () => mockRepo.read(id: notification.id),
        ).thenAnswer((_) async => notification);
      });

      test('returns 200 for owner marking as read', () async {
        final updatedNotification = notification.copyWith(
          readAt: DateTime.now(),
        );

        when(
          () => mockRepo.update(
            id: notification.id,
            item: any(named: 'item'),
          ),
        ).thenAnswer((_) async => updatedNotification);

        final response = await api.put(
          '/api/v1/data/${notification.id}?model=in_app_notification',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(updatedNotification.toJson()),
        );

        expect(response.statusCode, 200);
      });

      test('returns 403 for non-owner', () async {
        final response = await api.put(
          '/api/v1/data/${notification.id}?model=in_app_notification',
          headers: {'Authorization': 'Bearer $otherUserToken'},
          body: jsonEncode(notification.toJson()),
        );

        expect(response.statusCode, 403);
      });
    });

    group('DELETE /api/v1/data/:id?model=in_app_notification', () {
      setUp(() {
        when(
          () => mockRepo.read(id: notification.id),
        ).thenAnswer((_) async => notification);
        when(
          () => mockRepo.delete(
            id: notification.id,
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async {});
      });

      test('returns 204 for owner', () async {
        final response = await api.delete(
          '/api/v1/data/${notification.id}?model=in_app_notification',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 204);
      });

      test('returns 403 for non-owner', () async {
        final response = await api.delete(
          '/api/v1/data/${notification.id}?model=in_app_notification',
          headers: {'Authorization': 'Bearer $otherUserToken'},
        );

        expect(response.statusCode, 403);
      });
    });
  });
}
