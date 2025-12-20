import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/country_query_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../src/helpers/test_helpers.dart';
import 'test_api.dart';

class MockCountryQueryService extends Mock implements CountryQueryService {}

void main() {
  group('Country Integration Tests', () {
    late TestApi api;
    late MockDataRepository<Country> mockRepo;
    late MockAuthTokenService mockAuthTokenService;
    late MockCountryQueryService mockCountryQueryService;

    late User standardUser;
    late String standardToken;
    late Country country;

    setUpAll(() {
      registerSharedFallbackValues();
    });

    setUp(() {
      mockRepo = MockDataRepository<Country>();
      mockAuthTokenService = MockAuthTokenService();
      mockCountryQueryService = MockCountryQueryService();

      standardUser = User(
        id: 'standard-id',
        email: 'standard@test.com',
        appRole: AppUserRole.standardUser,
        dashboardRole: DashboardUserRole.none,
        createdAt: DateTime.now(),
        feedDecoratorStatus: const {},
      );
      standardToken = 'standard-token';

      when(
        () => mockAuthTokenService.validateToken(standardToken),
      ).thenAnswer((_) async => standardUser);

      country = Country(
        id: 'us',
        isoCode: 'US',
        name: 'United States',
        flagUrl: 'url',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      );

      api = TestApi.from(
        (context) => context
            .provide<DataRepository<Country>>(() => mockRepo)
            .provide<AuthTokenService>(() => mockAuthTokenService)
            .provide<CountryQueryService>(() => mockCountryQueryService),
      );
    });

    group('GET /api/v1/data?model=country', () {
      test('returns 200 for standard user', () async {
        when(
          () => mockRepo.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [country],
            cursor: null,
            hasMore: false,
          ),
        );

        final response = await api.get(
          '/api/v1/data?model=country',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
      });

      test('delegates to CountryQueryService for special filters', () async {
        when(
          () => mockCountryQueryService.getFilteredCountries(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async =>
              PaginatedResponse(items: [country], cursor: null, hasMore: false),
        );

        final response = await api.get(
          '/api/v1/data?model=country&filter={"hasActiveSources":true}',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
        verify(
          () => mockCountryQueryService.getFilteredCountries(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).called(1);
      });
    });

    group('POST /api/v1/data?model=country', () {
      test('returns 403 (unsupported)', () async {
        final response = await api.post(
          '/api/v1/data?model=country',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(country.toJson()),
        );
        expect(response.statusCode, 403);
      });
    });
  });
}
