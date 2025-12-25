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
  group('Engagement Integration Tests', () {
    late TestApi api;
    late MockDataRepository<Engagement> mockRepo;
    late MockAuthTokenService mockAuthTokenService;
    late MockUserActionLimitService mockUserActionLimitService;

    late User standardUser;
    late User otherUser;
    late String standardToken;
    late String otherUserToken;

    late Engagement engagement;

    setUpAll(() {
      registerSharedFallbackValues();
      registerFallbackValue(createTestUser(id: 'fallback'));
      registerFallbackValue(
        Engagement(
          id: 'fallback-id',
          userId: 'fallback-user',
          entityId: 'fallback-entity',
          entityType: EngageableType.headline,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          reaction: const Reaction(reactionType: ReactionType.like),
        ),
      );
    });

    setUp(() {
      mockRepo = MockDataRepository<Engagement>();
      mockAuthTokenService = MockAuthTokenService();
      mockUserActionLimitService = MockUserActionLimitService();

      standardUser = User(
        id: 'standard-id',
        email: 'standard@test.com',
        role: UserRole.user,
        tier: AccessTier.standard,
        createdAt: DateTime.now(),
      );
      otherUser = User(
        id: 'other-id',
        email: 'other@test.com',
        role: UserRole.user,
        tier: AccessTier.standard,
        createdAt: DateTime.now(),
      );

      standardToken = 'standard-token';
      otherUserToken = 'other-user-token';

      when(
        () => mockAuthTokenService.validateToken(standardToken),
      ).thenAnswer((_) async => standardUser);
      when(
        () => mockAuthTokenService.validateToken(otherUserToken),
      ).thenAnswer((_) async => otherUser);

      engagement = Engagement(
        id: 'eng-1',
        userId: standardUser.id,
        entityId: 'headline-1',
        entityType: EngageableType.headline,
        reaction: const Reaction(reactionType: ReactionType.like),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Default: limits passed
      when(
        () => mockUserActionLimitService.checkEngagementCreationLimit(
          user: any(named: 'user'),
          engagement: any(named: 'engagement'),
        ),
      ).thenAnswer((_) async {});

      api = TestApi.from(
        (context) => context
            .provide<DataRepository<Engagement>>(() => mockRepo)
            .provide<AuthTokenService>(() => mockAuthTokenService)
            .provide<UserActionLimitService>(() => mockUserActionLimitService),
      );
    });

    group('POST /api/v1/data?model=engagement', () {
      test('returns 201 for valid engagement', () async {
        // Mock duplicate check (return empty list)
        when(
          () => mockRepo.readAll(filter: any(named: 'filter')),
        ).thenAnswer(
          (_) async =>
              const PaginatedResponse(items: [], cursor: null, hasMore: false),
        );

        when(
          () => mockRepo.create(
            item: any(named: 'item'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (invocation) async => invocation.namedArguments[#item] as Engagement,
        );

        final response = await api.post(
          '/api/v1/data?model=engagement',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(engagement.toJson()),
        );

        expect(response.statusCode, 201);
        verify(
          () => mockUserActionLimitService.checkEngagementCreationLimit(
            user: standardUser,
            engagement: any(named: 'engagement'),
          ),
        ).called(1);
      });

      test('returns 409 for duplicate engagement', () async {
        // Mock duplicate check (return existing item)
        when(
          () => mockRepo.readAll(filter: any(named: 'filter')),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [engagement],
            cursor: null,
            hasMore: false,
          ),
        );

        final response = await api.post(
          '/api/v1/data?model=engagement',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(engagement.toJson()),
        );

        expect(response.statusCode, 409);
      });

      test('returns 403 when limit exceeded', () async {
        // Mock duplicate check (return empty list)
        when(
          () => mockRepo.readAll(filter: any(named: 'filter')),
        ).thenAnswer(
          (_) async =>
              const PaginatedResponse(items: [], cursor: null, hasMore: false),
        );

        when(
          () => mockUserActionLimitService.checkEngagementCreationLimit(
            user: any(named: 'user'),
            engagement: any(named: 'engagement'),
          ),
        ).thenThrow(const ForbiddenException('Limit exceeded'));

        final response = await api.post(
          '/api/v1/data?model=engagement',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(engagement.toJson()),
        );

        expect(response.statusCode, 403);
      });

      test('returns 403 if userId mismatches', () async {
        final otherEngagement = engagement.copyWith(userId: otherUser.id);

        final response = await api.post(
          '/api/v1/data?model=engagement',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(otherEngagement.toJson()),
        );

        expect(response.statusCode, 403);
      });
    });

    group('GET /api/v1/data/:id?model=engagement', () {
      test('returns 200 for owner', () async {
        when(
          () => mockRepo.read(id: engagement.id),
        ).thenAnswer((_) async => engagement);

        final response = await api.get(
          '/api/v1/data/${engagement.id}?model=engagement',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
      });

      test('returns 403 for non-owner', () async {
        when(
          () => mockRepo.read(id: engagement.id),
        ).thenAnswer((_) async => engagement);

        final response = await api.get(
          '/api/v1/data/${engagement.id}?model=engagement',
          headers: {'Authorization': 'Bearer $otherUserToken'},
        );

        expect(response.statusCode, 403);
      });
    });

    group('PUT /api/v1/data/:id?model=engagement', () {
      setUp(() {
        when(
          () => mockRepo.read(id: engagement.id),
        ).thenAnswer((_) async => engagement);
      });

      test('returns 200 for owner', () async {
        final updatedEngagement = engagement.copyWith(
          reaction: const ValueWrapper(
            Reaction(reactionType: ReactionType.angry),
          ),
        );

        when(
          () => mockRepo.update(
            id: engagement.id,
            item: any(named: 'item'),
          ),
        ).thenAnswer((_) async => updatedEngagement);

        final response = await api.put(
          '/api/v1/data/${engagement.id}?model=engagement',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(updatedEngagement.toJson()),
        );

        expect(response.statusCode, 200);
      });

      test('returns 403 for non-owner', () async {
        final response = await api.put(
          '/api/v1/data/${engagement.id}?model=engagement',
          headers: {'Authorization': 'Bearer $otherUserToken'},
          body: jsonEncode(engagement.toJson()),
        );

        expect(response.statusCode, 403);
      });
    });

    group('DELETE /api/v1/data/:id?model=engagement', () {
      setUp(() {
        when(
          () => mockRepo.read(id: engagement.id),
        ).thenAnswer((_) async => engagement);
        when(
          () => mockRepo.delete(
            id: engagement.id,
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async {});
      });

      test('returns 204 for owner', () async {
        final response = await api.delete(
          '/api/v1/data/${engagement.id}?model=engagement',
          headers: {'Authorization': 'Bearer $standardToken'},
        );
        expect(response.statusCode, 204);
      });
    });
  });
}
