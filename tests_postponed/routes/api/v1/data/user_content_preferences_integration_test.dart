import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/user_action_limit_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../test/src/helpers/test_helpers.dart';
import 'test_api.dart';

void main() {
  group('UserContentPreferences Integration Tests', () {
    late TestApi api;
    late MockDataRepository<UserContentPreferences> mockRepo;
    late MockAuthTokenService mockAuthTokenService;
    late MockUserActionLimitService mockUserActionLimitService;

    late User adminUser;
    late User standardUser;
    late User otherUser;
    late String adminToken;
    late String standardToken;
    late String otherUserToken;

    late UserContentPreferences standardUserPrefs;
    late UserContentPreferences otherUserPrefs;

    setUpAll(() {
      registerSharedFallbackValues();
      registerFallbackValue(const PaginationOptions());
      registerFallbackValue(const SortOption('createdAt'));
      registerFallbackValue(createTestUser(id: 'fallback'));
      registerFallbackValue(
        const UserContentPreferences(
          id: 'fallback-id',
          followedCountries: [],
          followedSources: [],
          followedTopics: [],
          savedHeadlines: [],
          savedHeadlineFilters: [],
          savedSourceFilters: [],
        ),
      );
    });

    setUp(() {
      mockRepo = MockDataRepository<UserContentPreferences>();
      mockAuthTokenService = MockAuthTokenService();
      mockUserActionLimitService = MockUserActionLimitService();

      adminUser = createTestUser(
        id: 'admin-id',
        email: 'admin@test.com',
        role: UserRole.admin,
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
      otherUserToken = 'other-user-token';

      when(
        () => mockAuthTokenService.validateToken(adminToken),
      ).thenAnswer((_) async => adminUser);
      when(
        () => mockAuthTokenService.validateToken(standardToken),
      ).thenAnswer((_) async => standardUser);
      when(
        () => mockAuthTokenService.validateToken(otherUserToken),
      ).thenAnswer((_) async => otherUser);

      standardUserPrefs = UserContentPreferences(
        id: standardUser.id,
        followedCountries: const [],
        followedSources: const [],
        followedTopics: const [],
        savedHeadlines: const [],
        savedHeadlineFilters: const [],
        savedSourceFilters: const [],
      );

      otherUserPrefs = UserContentPreferences(
        id: otherUser.id,
        followedCountries: const [],
        followedSources: const [],
        followedTopics: const [],
        savedHeadlines: const [],
        savedHeadlineFilters: const [],
        savedSourceFilters: const [],
      );

      // Default: limits are not exceeded
      when(
        () => mockUserActionLimitService.checkUserContentPreferencesLimits(
          user: any(named: 'user'),
          updatedPreferences: any(named: 'updatedPreferences'),
        ),
      ).thenAnswer((_) async {});

      api = TestApi.from(
        (context) => context
            .provide<DataRepository<UserContentPreferences>>(() => mockRepo)
            .provide<AuthTokenService>(() => mockAuthTokenService)
            .provide<UserActionLimitService>(() => mockUserActionLimitService),
      );
    });

    group('GET /api/v1/data/:id?model=user_content_preferences', () {
      test('returns 200 for admin user getting any user prefs', () async {
        when(
          () => mockRepo.read(id: standardUser.id),
        ).thenAnswer((_) async => standardUserPrefs);

        final response = await api.get(
          '/api/v1/data/${standardUser.id}?model=user_content_preferences',
          headers: {'Authorization': 'Bearer $adminToken'},
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(await response.body());
        expect(body['data']['id'], standardUser.id);
      });

      test('returns 200 for standard user getting their own prefs', () async {
        when(
          () => mockRepo.read(id: standardUser.id),
        ).thenAnswer((_) async => standardUserPrefs);

        final response = await api.get(
          '/api/v1/data/${standardUser.id}?model=user_content_preferences',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(await response.body());
        expect(body['data']['id'], standardUser.id);
      });

      test(
        'returns 403 for standard user getting another user prefs',
        () async {
          when(
            () => mockRepo.read(id: otherUser.id),
          ).thenAnswer((_) async => otherUserPrefs);

          final response = await api.get(
            '/api/v1/data/${otherUser.id}?model=user_content_preferences',
            headers: {'Authorization': 'Bearer $standardToken'},
          );

          expect(response.statusCode, 403);
        },
      );
    });

    group('PUT /api/v1/data/:id?model=user_content_preferences', () {
      setUp(() {
        // Pre-fetch middleware needs to find the item
        when(
          () => mockRepo.read(id: standardUser.id),
        ).thenAnswer((_) async => standardUserPrefs);
        when(
          () => mockRepo.read(id: otherUser.id),
        ).thenAnswer((_) async => otherUserPrefs);
      });

      test('returns 200 for admin user updating any user prefs', () async {
        final updatedPrefs = standardUserPrefs.copyWith(
          followedTopics: [
            Topic(
              id: 't1',
              name: 'Tech',
              description: '',
              iconUrl: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              status: ContentStatus.active,
            ),
          ],
        );

        when(
          () => mockRepo.update(
            id: standardUser.id,
            item: any(named: 'item'),
          ),
        ).thenAnswer((_) async => updatedPrefs);

        final response = await api.put(
          '/api/v1/data/${standardUser.id}?model=user_content_preferences',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(updatedPrefs.toJson()),
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(await response.body());
        expect(body['data']['followedTopics'], hasLength(1));
      });

      test('returns 200 for standard user updating their own prefs', () async {
        final updatedPrefs = standardUserPrefs.copyWith(
          followedTopics: [
            Topic(
              id: 't1',
              name: 'Tech',
              description: '',
              iconUrl: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              status: ContentStatus.active,
            ),
          ],
        );

        when(
          () => mockRepo.update(
            id: standardUser.id,
            item: any(named: 'item'),
          ),
        ).thenAnswer((_) async => updatedPrefs);

        final response = await api.put(
          '/api/v1/data/${standardUser.id}?model=user_content_preferences',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(updatedPrefs.toJson()),
        );

        expect(response.statusCode, 200);
        verify(
          () => mockUserActionLimitService.checkUserContentPreferencesLimits(
            user: standardUser,
            updatedPreferences: any(named: 'updatedPreferences'),
          ),
        ).called(1);
      });

      test('returns 403 when limits are exceeded', () async {
        when(
          () => mockUserActionLimitService.checkUserContentPreferencesLimits(
            user: any(named: 'user'),
            updatedPreferences: any(named: 'updatedPreferences'),
          ),
        ).thenThrow(const ForbiddenException('Limit exceeded'));

        final response = await api.put(
          '/api/v1/data/${standardUser.id}?model=user_content_preferences',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(standardUserPrefs.toJson()),
        );

        expect(response.statusCode, 403);
      });

      test(
        'returns 403 for standard user updating another user prefs',
        () async {
          final response = await api.put(
            '/api/v1/data/${otherUser.id}?model=user_content_preferences',
            headers: {'Authorization': 'Bearer $standardToken'},
            body: jsonEncode(otherUserPrefs.toJson()),
          );

          expect(response.statusCode, 403);
        },
      );
    });

    group('POST and DELETE', () {
      test('returns 403 for POST (unsupported)', () async {
        final response = await api.post(
          '/api/v1/data?model=user_content_preferences',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(standardUserPrefs.toJson()),
        );
        expect(response.statusCode, 403);
      });
    });
  });
}
