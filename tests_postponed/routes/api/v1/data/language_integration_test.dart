import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../test/src/helpers/test_helpers.dart';
import 'test_api.dart';

void main() {
  group('Language Integration Tests', () {
    late TestApi api;
    late MockDataRepository<Language> mockRepo;
    late MockAuthTokenService mockAuthTokenService;

    late User standardUser;
    late String standardToken;
    late Language language;

    setUpAll(() {
      registerSharedFallbackValues();
      registerFallbackValue(const PaginationOptions());
      registerFallbackValue(const SortOption('createdAt'));
      registerFallbackValue(
        Language(
          id: 'fallback-id',
          code: 'en',
          name: 'English',
          nativeName: 'English',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
        ),
      );
    });

    setUp(() {
      mockRepo = MockDataRepository<Language>();
      mockAuthTokenService = MockAuthTokenService();

      standardUser = createTestUser(
        id: 'standard-id',
        email: 'standard@test.com',
      );
      standardToken = 'standard-token';

      when(
        () => mockAuthTokenService.validateToken(standardToken),
      ).thenAnswer((_) async => standardUser);

      language = Language(
        id: 'en',
        code: 'en',
        name: 'English',
        nativeName: 'English',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      );

      api = TestApi.from(
        (context) => context
            .provide<DataRepository<Language>>(() => mockRepo)
            .provide<AuthTokenService>(() => mockAuthTokenService),
      );
    });

    group('GET /api/v1/data?model=language', () {
      test('returns 200 for standard user', () async {
        when(
          () => mockRepo.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [language],
            cursor: null,
            hasMore: false,
          ),
        );

        final response = await api.get(
          '/api/v1/data?model=language',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
      });
    });

    group('POST /api/v1/data?model=language', () {
      test('returns 403 (unsupported)', () async {
        final response = await api.post(
          '/api/v1/data?model=language',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(language.toJson()),
        );
        expect(response.statusCode, 403);
      });
    });
  });
}
