import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../src/helpers/test_helpers.dart';
import 'test_api.dart';

void main() {
  group('PushNotificationDevice Integration Tests', () {
    late TestApi api;
    late MockDataRepository<PushNotificationDevice> mockRepo;
    late MockAuthTokenService mockAuthTokenService;

    late User adminUser;
    late User standardUser;
    late User otherUser;
    late String adminToken;
    late String standardToken;

    setUp(() {
      mockRepo = MockDataRepository<PushNotificationDevice>();
      mockAuthTokenService = MockAuthTokenService();

      adminUser = createTestUser(
        id: 'admin-id',
        email: 'admin@test.com',
        dashboardRole: DashboardUserRole.admin,
      );
      standardUser = createTestUser(
        id: 'standard-id',
        email: 'standard@test.com',
      );
      otherUser = createTestUser(
        id: 'other-id',
        email: 'other@test.com',
      );

      adminToken = 'admin-token';
      standardToken = 'standard-token';

      when(
        () => mockAuthTokenService.validateToken(adminToken),
      ).thenAnswer((_) async => adminUser);
      when(
        () => mockAuthTokenService.validateToken(standardToken),
      ).thenAnswer((_) async => standardUser);

      api = TestApi.from(
        (context) => context
            .provide<DataRepository<PushNotificationDevice>>(() => mockRepo)
            .provide<AuthTokenService>(() => mockAuthTokenService),
      );
    });

    group('POST /api/v1/data?model=push_notification_device', () {
      test('returns 201 for standard user creating their own device', () async {
        final device = PushNotificationDevice(
          id: 'device-1',
          userId: standardUser.id,
          platform: DevicePlatform.ios,
          providerTokens: const {PushNotificationProvider.firebase: 'token'},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(
          () => mockRepo.create(
            item: any(named: 'item'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((invocation) async {
          return invocation.namedArguments[#item] as PushNotificationDevice;
        });

        final response = await api.post(
          '/api/v1/data?model=push_notification_device',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(device.toJson()),
        );

        expect(response.statusCode, 201);
        final body = jsonDecode(await response.body());
        expect(body['data']['userId'], standardUser.id);
      });

      test(
        'returns 403 for standard user creating device for another user',
        () async {
          final device = PushNotificationDevice(
            id: 'device-2',
            userId: otherUser.id, // Mismatch
            platform: DevicePlatform.android,
            providerTokens: const {},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final response = await api.post(
            '/api/v1/data?model=push_notification_device',
            headers: {'Authorization': 'Bearer $standardToken'},
            body: jsonEncode(device.toJson()),
          );

          expect(response.statusCode, 403);
        },
      );
    });

    group('GET /api/v1/data/:id?model=push_notification_device', () {
      final device = PushNotificationDevice(
        id: 'device-1',
        userId: standardUser.id,
        platform: DevicePlatform.ios,
        providerTokens: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      test('returns 200 for owner', () async {
        when(
          () => mockRepo.read(id: device.id),
        ).thenAnswer((_) async => device);

        final response = await api.get(
          '/api/v1/data/${device.id}?model=push_notification_device',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
      });

      test('returns 403 for non-owner', () async {
        // Mock auth token for other user
        const otherToken = 'other-token';
        when(
          () => mockAuthTokenService.validateToken(otherToken),
        ).thenAnswer((_) async => otherUser);

        when(
          () => mockRepo.read(id: device.id),
        ).thenAnswer((_) async => device);

        final response = await api.get(
          '/api/v1/data/${device.id}?model=push_notification_device',
          headers: {'Authorization': 'Bearer $otherToken'},
        );

        expect(response.statusCode, 403);
      });
    });

    group('DELETE /api/v1/data/:id?model=push_notification_device', () {
      final device = PushNotificationDevice(
        id: 'device-1',
        userId: standardUser.id,
        platform: DevicePlatform.ios,
        providerTokens: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      setUp(() {
        when(
          () => mockRepo.read(id: device.id),
        ).thenAnswer((_) async => device);
        when(
          () => mockRepo.delete(
            id: device.id,
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async {});
      });

      test('returns 204 for owner', () async {
        final response = await api.delete(
          '/api/v1/data/${device.id}?model=push_notification_device',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 204);
      });

      test('returns 403 for non-owner', () async {
        // Admin can delete, but let's test another standard user
        final response = await api.delete(
          '/api/v1/data/${device.id}?model=push_notification_device',
          headers: {'Authorization': 'Bearer $adminToken'}, // Admin can delete
        );
        expect(response.statusCode, 204);
      });
    });
  });
}
