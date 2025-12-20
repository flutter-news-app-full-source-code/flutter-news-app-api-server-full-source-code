import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/user_action_limit_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../src/helpers/test_helpers.dart';
import 'test_api.dart';

void main() {
  group('Report Integration Tests', () {
    late TestApi api;
    late MockDataRepository<Report> mockRepo;
    late MockAuthTokenService mockAuthTokenService;
    late MockUserActionLimitService mockUserActionLimitService;

    late User standardUser;
    late User otherUser;
    late String standardToken;

    late Report report;

    setUpAll(() {
      registerSharedFallbackValues();
      registerFallbackValue(const PaginationOptions());
      registerFallbackValue(const SortOption('createdAt'));
      registerFallbackValue(createTestUser(id: 'fallback'));
      registerFallbackValue(
        Report(
          id: 'fallback-id',
          reporterUserId: 'fallback-user',
          entityType: ReportableEntity.headline,
          entityId: 'fallback-entity',
          reason: 'spam',
          status: ModerationStatus.pendingReview,
          createdAt: DateTime.now(),
        ),
      );
    });

    setUp(() {
      mockRepo = MockDataRepository<Report>();
      mockAuthTokenService = MockAuthTokenService();
      mockUserActionLimitService = MockUserActionLimitService();

      standardUser = createTestUser(
        id: 'standard-id',
        email: 'standard@test.com',
      );
      otherUser = createTestUser(
        id: 'other-id',
        email: 'other@test.com',
      );

      standardToken = 'standard-token';

      when(
        () => mockAuthTokenService.validateToken(standardToken),
      ).thenAnswer((_) async => standardUser);

      report = Report(
        id: 'rep-1',
        reporterUserId: standardUser.id,
        entityType: ReportableEntity.headline,
        entityId: 'h1',
        reason: HeadlineReportReason.clickbaitTitle.name,
        status: ModerationStatus.pendingReview,
        createdAt: DateTime.now(),
      );

      when(
        () => mockUserActionLimitService.checkReportCreationLimit(
          user: any(named: 'user'),
        ),
      ).thenAnswer((_) async {});

      api = TestApi.from(
        (context) => context
            .provide<DataRepository<Report>>(() => mockRepo)
            .provide<AuthTokenService>(() => mockAuthTokenService)
            .provide<UserActionLimitService>(() => mockUserActionLimitService),
      );
    });

    group('POST /api/v1/data?model=report', () {
      test('returns 201 for valid report', () async {
        when(
          () => mockRepo.create(item: any(named: 'item')),
        ).thenAnswer(
          (invocation) async => invocation.namedArguments[#item] as Report,
        );

        final response = await api.post(
          '/api/v1/data?model=report',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(report.toJson()),
        );

        expect(response.statusCode, 201);
        verify(
          () => mockUserActionLimitService.checkReportCreationLimit(
            user: standardUser,
          ),
        ).called(1);
      });

      test('returns 403 when limit exceeded', () async {
        when(
          () => mockUserActionLimitService.checkReportCreationLimit(
            user: any(named: 'user'),
          ),
        ).thenThrow(const ForbiddenException('Limit exceeded'));

        final response = await api.post(
          '/api/v1/data?model=report',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(report.toJson()),
        );

        expect(response.statusCode, 403);
      });

      test('returns 403 if reporterUserId mismatches', () async {
        final otherReport = report.copyWith(reporterUserId: otherUser.id);

        final response = await api.post(
          '/api/v1/data?model=report',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(otherReport.toJson()),
        );

        expect(response.statusCode, 403);
      });
    });

    group('GET /api/v1/data?model=report', () {
      test('returns 200 for owner', () async {
        when(
          () => mockRepo.readAll(
            userId: standardUser.id,
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async =>
              PaginatedResponse(items: [report], cursor: null, hasMore: false),
        );

        final response = await api.get(
          '/api/v1/data?model=report',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
      });
    });
  });
}
