import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../src/helpers/test_helpers.dart';
import 'test_api.dart';

void main() {
  group('AppReview Integration Tests', () {
    late TestApi api;
    late MockDataRepository<AppReview> mockRepo;
    late MockAuthTokenService mockAuthTokenService;

    late User standardUser;
    late User otherUser;
    late String standardToken;
    late String otherUserToken;

    late AppReview appReview;

    setUp(() {
      mockRepo = MockDataRepository<AppReview>();
      mockAuthTokenService = MockAuthTokenService();

      standardUser = User(
        id: 'standard-id',
        email: 'standard@test.com',
        appRole: AppUserRole.standardUser,
        dashboardRole: DashboardUserRole.none,
        createdAt: DateTime.now(),
        feedDecoratorStatus: const {},
      );
      otherUser = User(
        id: 'other-id',
        email: 'other@test.com',
        appRole: AppUserRole.standardUser,
        dashboardRole: DashboardUserRole.none,
        createdAt: DateTime.now(),
        feedDecoratorStatus: const {},
      );

      standardToken = 'standard-token';
      otherUserToken = 'other-user-token';

      when(
        () => mockAuthTokenService.validateToken(standardToken),
      ).thenAnswer((_) async => standardUser);
      when(
        () => mockAuthTokenService.validateToken(otherUserToken),
      ).thenAnswer((_) async => otherUser);

      appReview = AppReview(
        id: 'rev-1',
        userId: standardUser.id,
        feedback: AppReviewFeedback.positive,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      api = TestApi.from(
        (context) => context
            .provide<DataRepository<AppReview>>(() => mockRepo)
            .provide<AuthTokenService>(() => mockAuthTokenService),
      );
    });

    group('POST /api/v1/data?model=app_review', () {
      test('returns 201 for valid review', () async {
        // Mock duplicate check (return empty list)
        when(
          () => mockRepo.readAll(filter: any(named: 'filter')),
        ).thenAnswer(
          (_) async =>
              const PaginatedResponse(items: [], cursor: null, hasMore: false),
        );

        when(
          () => mockRepo.create(item: any(named: 'item')),
        ).thenAnswer(
          (invocation) async => invocation.namedArguments[#item] as AppReview,
        );

        final response = await api.post(
          '/api/v1/data?model=app_review',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(appReview.toJson()),
        );

        expect(response.statusCode, 201);
      });

      test('returns 409 for duplicate review', () async {
        // Mock duplicate check (return existing item)
        when(
          () => mockRepo.readAll(filter: any(named: 'filter')),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [appReview],
            cursor: null,
            hasMore: false,
          ),
        );

        final response = await api.post(
          '/api/v1/data?model=app_review',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(appReview.toJson()),
        );

        expect(response.statusCode, 409);
      });

      test('returns 403 if userId mismatches', () async {
        final otherReview = appReview.copyWith(userId: otherUser.id);

        final response = await api.post(
          '/api/v1/data?model=app_review',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(otherReview.toJson()),
        );

        expect(response.statusCode, 403);
      });
    });

    group('GET /api/v1/data/:id?model=app_review', () {
      test('returns 200 for owner', () async {
        when(
          () => mockRepo.read(id: appReview.id),
        ).thenAnswer((_) async => appReview);

        final response = await api.get(
          '/api/v1/data/${appReview.id}?model=app_review',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
      });

      test('returns 403 for non-owner', () async {
        when(
          () => mockRepo.read(id: appReview.id),
        ).thenAnswer((_) async => appReview);

        final response = await api.get(
          '/api/v1/data/${appReview.id}?model=app_review',
          headers: {'Authorization': 'Bearer $otherUserToken'},
        );

        expect(response.statusCode, 403);
      });
    });

    group('PUT /api/v1/data/:id?model=app_review', () {
      setUp(() {
        when(
          () => mockRepo.read(id: appReview.id),
        ).thenAnswer((_) async => appReview);
      });

      test('returns 200 for owner', () async {
        final updatedReview = appReview.copyWith(
          feedbackDetails: const ValueWrapper('Great app!'),
        );

        when(
          () => mockRepo.update(
            id: appReview.id,
            item: any(named: 'item'),
          ),
        ).thenAnswer((_) async => updatedReview);

        final response = await api.put(
          '/api/v1/data/${appReview.id}?model=app_review',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(updatedReview.toJson()),
        );

        expect(response.statusCode, 200);
      });
    });
  });
}
