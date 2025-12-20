import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../src/helpers/test_helpers.dart';
import 'test_api.dart';

void main() {
  group('RankedListCardData Integration Tests', () {
    late TestApi api;
    late MockDataRepository<RankedListCardData> mockRepo;
    late MockAuthTokenService mockAuthTokenService;

    late User adminUser;
    late User standardUser;
    late String adminToken;
    late String standardToken;

    late RankedListCardData rankedListCard;

    setUpAll(() {
      registerSharedFallbackValues();
      registerFallbackValue(const PaginationOptions());
      registerFallbackValue(const SortOption('createdAt'));
      registerFallbackValue(
        const RankedListCardData(
          id: RankedListCardId.overviewHeadlinesMostViewed,
          label: 'Fallback',
          timeFrames: {},
        ),
      );
    });

    setUp(() {
      mockRepo = MockDataRepository<RankedListCardData>();
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

      rankedListCard = const RankedListCardData(
        id: RankedListCardId.overviewHeadlinesMostViewed,
        label: 'Most Viewed',
        timeFrames: {
          RankedListTimeFrame.week: [
            RankedListItem(
              entityId: 'h1',
              displayTitle: 'Headline 1',
              metricValue: 100,
            ),
          ],
        },
      );

      api = TestApi.from(
        (context) => context
            .provide<DataRepository<RankedListCardData>>(() => mockRepo)
            .provide<AuthTokenService>(() => mockAuthTokenService),
      );
    });

    group('GET /api/v1/data?model=ranked_list_card_data', () {
      test('returns 200 for admin user', () async {
        when(
          () => mockRepo.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [rankedListCard],
            cursor: null,
            hasMore: false,
          ),
        );

        final response = await api.get(
          '/api/v1/data?model=ranked_list_card_data',
          headers: {'Authorization': 'Bearer $adminToken'},
        );

        expect(response.statusCode, 200);
      });

      test('returns 403 for standard user', () async {
        final response = await api.get(
          '/api/v1/data?model=ranked_list_card_data',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 403);
      });
    });

    group('GET /api/v1/data/:id?model=ranked_list_card_data', () {
      test('returns 200 for admin user', () async {
        when(
          () => mockRepo.read(id: rankedListCard.id.name),
        ).thenAnswer((_) async => rankedListCard);

        final response = await api.get(
          '/api/v1/data/${rankedListCard.id.name}?model=ranked_list_card_data',
          headers: {'Authorization': 'Bearer $adminToken'},
        );

        expect(response.statusCode, 200);
      });

      test('returns 403 for standard user', () async {
        final response = await api.get(
          '/api/v1/data/${rankedListCard.id.name}?model=ranked_list_card_data',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 403);
      });
    });

    group('POST /api/v1/data?model=ranked_list_card_data', () {
      test('returns 403 (unsupported)', () async {
        final response = await api.post(
          '/api/v1/data?model=ranked_list_card_data',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(rankedListCard.toJson()),
        );

        expect(response.statusCode, 403);
      });
    });
  });
}
