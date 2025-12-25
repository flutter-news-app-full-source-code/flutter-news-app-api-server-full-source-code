import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../test/src/helpers/test_helpers.dart';
import 'test_api.dart';

void main() {
  group('ChartCardData Integration Tests', () {
    late TestApi api;
    late MockDataRepository<ChartCardData> mockRepo;
    late MockAuthTokenService mockAuthTokenService;

    late User adminUser;
    late User standardUser;
    late String adminToken;
    late String standardToken;

    late ChartCardData chartCard;

    setUpAll(registerSharedFallbackValues);

    setUp(() {
      mockRepo = MockDataRepository<ChartCardData>();
      mockAuthTokenService = MockAuthTokenService();

      adminUser = User(
        id: 'admin-id',
        email: 'admin@test.com',
        role: UserRole.admin,
        tier: AccessTier.premium,
        createdAt: DateTime.now(),
      );
      standardUser = User(
        id: 'standard-id',
        email: 'standard@test.com',
        role: UserRole.user,
        tier: AccessTier.standard,
        createdAt: DateTime.now(),
      );

      adminToken = 'admin-token';
      standardToken = 'standard-token';

      when(
        () => mockAuthTokenService.validateToken(adminToken),
      ).thenAnswer((_) async => adminUser);
      when(
        () => mockAuthTokenService.validateToken(standardToken),
      ).thenAnswer((_) async => standardUser);

      chartCard = const ChartCardData(
        id: ChartCardId.usersRegistrationsOverTime,
        label: 'Registrations',
        type: ChartType.line,
        timeFrames: {
          ChartTimeFrame.week: [DataPoint(value: 5, label: 'Mon')],
        },
      );

      api = TestApi.from(
        (context) => context
            .provide<DataRepository<ChartCardData>>(() => mockRepo)
            .provide<AuthTokenService>(() => mockAuthTokenService),
      );
    });

    group('GET /api/v1/data?model=chart_card_data', () {
      test('returns 200 for admin user', () async {
        when(
          () => mockRepo.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [chartCard],
            cursor: null,
            hasMore: false,
          ),
        );

        final response = await api.get(
          '/api/v1/data?model=chart_card_data',
          headers: {'Authorization': 'Bearer $adminToken'},
        );

        expect(response.statusCode, 200);
      });

      test('returns 403 for standard user', () async {
        final response = await api.get(
          '/api/v1/data?model=chart_card_data',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 403);
      });
    });

    group('GET /api/v1/data/:id?model=chart_card_data', () {
      test('returns 200 for admin user', () async {
        when(
          () => mockRepo.read(id: chartCard.id.name),
        ).thenAnswer((_) async => chartCard);

        final response = await api.get(
          '/api/v1/data/${chartCard.id.name}?model=chart_card_data',
          headers: {'Authorization': 'Bearer $adminToken'},
        );

        expect(response.statusCode, 200);
      });

      test('returns 403 for standard user', () async {
        final response = await api.get(
          '/api/v1/data/${chartCard.id.name}?model=chart_card_data',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 403);
      });
    });

    group('POST /api/v1/data?model=chart_card_data', () {
      test('returns 403 (unsupported)', () async {
        final response = await api.post(
          '/api/v1/data?model=chart_card_data',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(chartCard.toJson()),
        );

        // Expect 403 because the action is marked as unsupported in ModelRegistry,
        // and AuthorizationMiddleware throws ForbiddenException for unsupported actions.
        expect(response.statusCode, 403);
      });
    });
  });
}
