import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../src/helpers/test_helpers.dart';
import 'test_api.dart';

void main() {
  group('Source Integration Tests', () {
    late TestApi api;
    late MockDataRepository<Source> mockRepo;
    late MockAuthTokenService mockAuthTokenService;

    late User adminUser;
    late User standardUser;
    late String adminToken;
    late String standardToken;

    late Source source;

    setUp(() {
      mockRepo = MockDataRepository<Source>();
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

      source = Source(
        id: 'source-1',
        name: 'Tech Daily',
        description: 'Daily tech news',
        url: 'url',
        logoUrl: 'logo',
        sourceType: SourceType.blog,
        language: Language(
          id: 'en',
          code: 'en',
          name: 'English',
          nativeName: 'English',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
        ),
        headquarters: Country(
          id: 'us',
          isoCode: 'US',
          name: 'United States',
          flagUrl: 'url',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      );

      api = TestApi.from(
        (context) => context
            .provide<DataRepository<Source>>(() => mockRepo)
            .provide<AuthTokenService>(() => mockAuthTokenService),
      );
    });

    group('GET /api/v1/data?model=source', () {
      test('returns 200 for standard user', () async {
        when(
          () => mockRepo.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [source],
            cursor: null,
            hasMore: false,
          ),
        );

        final response = await api.get(
          '/api/v1/data?model=source',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
      });
    });

    group('POST /api/v1/data?model=source', () {
      test('returns 201 for admin user', () async {
        when(
          () => mockRepo.create(
            item: any(named: 'item'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (invocation) async => invocation.namedArguments[#item] as Source,
        );

        final response = await api.post(
          '/api/v1/data?model=source',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(source.toJson()),
        );

        expect(response.statusCode, 201);
      });

      test('returns 403 for standard user', () async {
        final response = await api.post(
          '/api/v1/data?model=source',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(source.toJson()),
        );

        expect(response.statusCode, 403);
      });
    });

    group('PUT /api/v1/data/:id?model=source', () {
      setUp(() {
        when(
          () => mockRepo.read(id: source.id),
        ).thenAnswer((_) async => source);
      });

      test('returns 200 for admin user', () async {
        final updatedSource = source.copyWith(name: 'Updated Tech Daily');
        when(
          () => mockRepo.update(
            id: source.id,
            item: any(named: 'item'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => updatedSource);

        final response = await api.put(
          '/api/v1/data/${source.id}?model=source',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(updatedSource.toJson()),
        );

        expect(response.statusCode, 200);
      });

      test('returns 403 for standard user', () async {
        final response = await api.put(
          '/api/v1/data/${source.id}?model=source',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(source.toJson()),
        );

        expect(response.statusCode, 403);
      });
    });

    group('DELETE /api/v1/data/:id?model=source', () {
      setUp(() {
        when(
          () => mockRepo.read(id: source.id),
        ).thenAnswer((_) async => source);
        when(
          () => mockRepo.delete(
            id: source.id,
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async {});
      });

      test('returns 204 for admin user', () async {
        final response = await api.delete(
          '/api/v1/data/${source.id}?model=source',
          headers: {'Authorization': 'Bearer $adminToken'},
        );

        expect(response.statusCode, 204);
      });

      test('returns 403 for standard user', () async {
        final response = await api.delete(
          '/api/v1/data/${source.id}?model=source',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 403);
      });
    });
  });
}
