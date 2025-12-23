import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../src/helpers/test_helpers.dart';
import 'test_api.dart';

void main() {
  group('User Integration Tests', () {
    late TestApi api;
    late MockDataRepository<User> mockUserRepository;
    late MockAuthTokenService mockAuthTokenService;

    late User adminUser;
    late User standardUser;
    late String adminToken;
    late String standardToken;

    setUpAll(() {
      registerSharedFallbackValues();
      registerFallbackValue(const PaginationOptions());
      registerFallbackValue(const SortOption('createdAt'));
      registerFallbackValue(createTestUser(id: 'fallback'));
    });

    setUp(() {
      mockUserRepository = MockUserRepository();
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
            .provide<DataRepository<User>>(() => mockUserRepository)
            .provide<AuthTokenService>(() => mockAuthTokenService),
      );
    });

    group('GET /api/v1/data?model=user (Collection)', () {
      test('returns 200 for admin user', () async {
        when(
          () => mockUserRepository.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [standardUser],
            cursor: null,
            hasMore: false,
          ),
        );

        final response = await api.get(
          '/api/v1/data?model=user',
          headers: {'Authorization': 'Bearer $adminToken'},
        );

        expect(response.statusCode, 200);
      });

      test('returns 403 for standard user', () async {
        final response = await api.get(
          '/api/v1/data?model=user',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 403);
      });
    });

    group('GET /api/v1/data/:id?model=user (Item)', () {
      test('returns 200 for admin user getting another user', () async {
        when(
          () => mockUserRepository.read(id: standardUser.id),
        ).thenAnswer((_) async => standardUser);

        final response = await api.get(
          '/api/v1/data/${standardUser.id}?model=user',
          headers: {'Authorization': 'Bearer $adminToken'},
        );

        expect(response.statusCode, 200);
      });

      test('returns 200 for standard user getting their own profile', () async {
        when(
          () => mockUserRepository.read(id: standardUser.id),
        ).thenAnswer((_) async => standardUser);

        final response = await api.get(
          '/api/v1/data/${standardUser.id}?model=user',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
      });

      test('returns 403 for standard user getting another user', () async {
        when(
          () => mockUserRepository.read(id: adminUser.id),
        ).thenAnswer((_) async => adminUser);

        final response = await api.get(
          '/api/v1/data/${adminUser.id}?model=user',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 403);
      });
    });

    group('PUT /api/v1/data/:id?model=user', () {
      setUp(() {
        // Pre-fetch middleware needs to find the item
        when(
          () => mockUserRepository.read(id: standardUser.id),
        ).thenAnswer((_) async => standardUser);
      });

      test('returns 200 for admin updating another user role', () async {
        final updatedUser = standardUser.copyWith(
          appRole: AppUserRole.premiumUser,
        );

        when(
          () => mockUserRepository.update(
            id: standardUser.id,
            item: any(named: 'item'),
          ),
        ).thenAnswer((_) async => updatedUser);

        final response = await api.put(
          '/api/v1/data/${standardUser.id}?model=user',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(updatedUser.toJson()),
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(await response.body());
        expect(body['data']['appRole'], 'premiumUser');
      });

      test('returns 403 for admin updating a non-role field', () async {
        final updatedUser = standardUser.copyWith(email: 'new@email.com');

        final response = await api.put(
          '/api/v1/data/${standardUser.id}?model=user',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(updatedUser.toJson()),
        );

        expect(response.statusCode, 403);
      });

      test(
        'returns 200 for standard user updating their feedDecoratorStatus',
        () async {
          final updatedUser = standardUser.copyWith(
            feedDecoratorStatus: {
              FeedDecoratorType.rateApp: const UserFeedDecoratorStatus(
                isCompleted: true,
              ),
            },
          );

          when(
            () => mockUserRepository.update(
              id: standardUser.id,
              item: any(named: 'item'),
            ),
          ).thenAnswer((_) async => updatedUser);

          final response = await api.put(
            '/api/v1/data/${standardUser.id}?model=user',
            headers: {'Authorization': 'Bearer $standardToken'},
            body: jsonEncode(updatedUser.toJson()),
          );

          expect(response.statusCode, 200);
          final body = jsonDecode(await response.body());
          expect(
            body['data']['feedDecoratorStatus']['rateApp']['isCompleted'],
            isTrue,
          );
        },
      );

      test('returns 403 for standard user updating their own role', () async {
        final updatedUser = standardUser.copyWith(
          appRole: AppUserRole.premiumUser,
        );

        final response = await api.put(
          '/api/v1/data/${standardUser.id}?model=user',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(updatedUser.toJson()),
        );

        expect(response.statusCode, 403);
      });

      test('returns 403 for standard user updating another user', () async {
        final updatedUser = adminUser.copyWith(
          feedDecoratorStatus: {
            FeedDecoratorType.rateApp: const UserFeedDecoratorStatus(
              isCompleted: true,
            ),
          },
        );

        // Need to mock the fetch for the other user
        when(
          () => mockUserRepository.read(id: adminUser.id),
        ).thenAnswer((_) async => adminUser);

        final response = await api.put(
          '/api/v1/data/${adminUser.id}?model=user',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(updatedUser.toJson()),
        );

        expect(response.statusCode, 403);
      });
    });

    group('POST and DELETE', () {
      test('returns 403 for POST (unsupported)', () async {
        final response = await api.post(
          '/api/v1/data?model=user',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(standardUser.toJson()),
        );
        expect(response.statusCode, 403);
      });

      test('returns 403 for DELETE (unsupported)', () async {
        final response = await api.delete(
          '/api/v1/data/${standardUser.id}?model=user',
          headers: {'Authorization': 'Bearer $adminToken'},
        );
        expect(response.statusCode, 403);
      });
    });
  });
}
