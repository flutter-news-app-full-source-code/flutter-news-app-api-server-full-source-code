import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../src/helpers/test_helpers.dart';
import 'test_api.dart';

void main() {
  group('Headline Integration Tests', () {
    late TestApi api;
    late MockDataRepository<Headline> mockHeadlineRepository;
    late MockAuthTokenService mockAuthTokenService;

    late User adminUser;
    late User standardUser;
    late String adminToken;
    late String standardToken;

    setUpAll(() {
      registerSharedFallbackValues();
      registerFallbackValue(const PaginationOptions());
      registerFallbackValue(const SortOption('createdAt'));
      registerFallbackValue(
        Headline(
          id: 'fallback-id',
          title: 'Fallback Title',
          url: 'http://fallback.com',
          imageUrl: 'http://fallback.com/image.png',
          source: Source(
            id: 's1',
            name: 'Source',
            description: 'Desc',
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
              name: 'USA',
              flagUrl: 'flag',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              status: ContentStatus.active,
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
          eventCountry: Country(
            id: 'us',
            isoCode: 'US',
            name: 'USA',
            flagUrl: 'flag',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
          topic: Topic(
            id: 't1',
            name: 'Topic',
            description: 'Desc',
            iconUrl: 'icon',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
          isBreaking: false,
        ),
      );
    });

    setUp(() {
      mockHeadlineRepository = MockHeadlineRepository();
      mockAuthTokenService = MockAuthTokenService();

      adminUser = createTestUser(
        id: 'admin-id',
        email: 'admin@test.com',
        role: UserRole.admin,
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
            .provide<DataRepository<Headline>>(() => mockHeadlineRepository)
            .provide<AuthTokenService>(() => mockAuthTokenService),
      );
    });

    final headline = Headline(
      id: 'h1',
      title: 'Test Headline',
      url: 'http://test.com',
      imageUrl: 'http://image.com',
      source: Source(
        id: 's1',
        name: 'Source',
        description: 'Desc',
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
          name: 'USA',
          flagUrl: 'flag',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      ),
      eventCountry: Country(
        id: 'us',
        isoCode: 'US',
        name: 'USA',
        flagUrl: 'flag',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      ),
      topic: Topic(
        id: 't1',
        name: 'Topic',
        description: 'Desc',
        iconUrl: 'icon',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
      isBreaking: false,
    );

    group('GET /api/v1/data?model=headline (Collection)', () {
      test('returns 200 for admin user', () async {
        when(
          () => mockHeadlineRepository.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [headline],
            cursor: null,
            hasMore: false,
          ),
        );

        final response = await api.get(
          '/api/v1/data?model=headline',
          headers: {'Authorization': 'Bearer $adminToken'},
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(await response.body());
        expect(body['data']['items'], isA<List<dynamic>>());
      });

      test('returns 200 for standard user', () async {
        when(
          () => mockHeadlineRepository.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [headline],
            cursor: null,
            hasMore: false,
          ),
        );

        final response = await api.get(
          '/api/v1/data?model=headline',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
      });

      test('returns 401 for unauthenticated user', () async {
        final response = await api.get('/api/v1/data?model=headline');
        expect(response.statusCode, 401);
      });
    });

    group('GET /api/v1/data/:id?model=headline (Item)', () {
      final itemHeadline = headline.copyWith(id: 'headline-123');

      test('returns 200 for standard user', () async {
        when(
          () => mockHeadlineRepository.read(id: 'headline-123'),
        ).thenAnswer((_) async => itemHeadline);

        final response = await api.get(
          '/api/v1/data/headline-123?model=headline',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(await response.body());
        expect(body['data']['id'], 'headline-123');
      });

      test('returns 404 for non-existent item', () async {
        when(
          () => mockHeadlineRepository.read(id: 'not-found'),
        ).thenThrow(const NotFoundException('Item not found'));

        final response = await api.get(
          '/api/v1/data/not-found?model=headline',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 404);
      });

      test('returns 401 for unauthenticated user', () async {
        final response = await api.get(
          '/api/v1/data/headline-123?model=headline',
        );
        expect(response.statusCode, 401);
      });
    });

    group('POST /api/v1/data?model=headline', () {
      final newHeadline = headline.copyWith(id: 'new-headline');

      test('returns 201 for admin user', () async {
        when(
          () => mockHeadlineRepository.create(
            item: any(named: 'item'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((invocation) async {
          final item = invocation.namedArguments[#item] as Headline;
          return item;
        });

        final response = await api.post(
          '/api/v1/data?model=headline',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(newHeadline.toJson()..remove('id')),
        );

        expect(response.statusCode, 201);
        final body = jsonDecode(await response.body());
        expect(body['data']['title'], newHeadline.title);
      });

      test('returns 403 for standard user', () async {
        final response = await api.post(
          '/api/v1/data?model=headline',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(newHeadline.toJson()..remove('id')),
        );

        expect(response.statusCode, 403);
      });

      test('returns 401 for unauthenticated user', () async {
        final response = await api.post(
          '/api/v1/data?model=headline',
          body: jsonEncode(newHeadline.toJson()..remove('id')),
        );

        expect(response.statusCode, 401);
      });

      test('returns 400 for malformed body', () async {
        final response = await api.post(
          '/api/v1/data?model=headline',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode({'invalid': 'body'}),
        );

        expect(response.statusCode, 400);
      });
    });

    group('PUT /api/v1/data/:id?model=headline', () {
      final existingHeadline = headline.copyWith(id: 'headline-123');
      final updatedHeadline = existingHeadline.copyWith(title: 'Updated Title');

      setUp(() {
        // Pre-fetch middleware needs to find the item
        when(
          () => mockHeadlineRepository.read(id: 'headline-123'),
        ).thenAnswer((_) async => existingHeadline);
      });

      test('returns 200 for admin user', () async {
        when(
          () => mockHeadlineRepository.update(
            id: 'headline-123',
            item: any(named: 'item'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => updatedHeadline);

        final response = await api.put(
          '/api/v1/data/headline-123?model=headline',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(updatedHeadline.toJson()),
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(await response.body());
        expect(body['data']['title'], 'Updated Title');
      });

      test('returns 403 for standard user', () async {
        final response = await api.put(
          '/api/v1/data/headline-123?model=headline',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(updatedHeadline.toJson()),
        );

        expect(response.statusCode, 403);
      });

      test('returns 401 for unauthenticated user', () async {
        final response = await api.put(
          '/api/v1/data/headline-123?model=headline',
          body: jsonEncode(updatedHeadline.toJson()),
        );

        expect(response.statusCode, 401);
      });

      test('returns 400 for body with mismatched ID', () async {
        final mismatchedBody = updatedHeadline.copyWith(id: 'wrong-id');

        final response = await api.put(
          '/api/v1/data/headline-123?model=headline',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(mismatchedBody.toJson()),
        );

        expect(response.statusCode, 400);
      });
    });

    group('DELETE /api/v1/data/:id?model=headline', () {
      final existingHeadline = headline.copyWith(id: 'headline-123');

      setUp(() {
        // Pre-fetch middleware needs to find the item
        when(
          () => mockHeadlineRepository.read(id: 'headline-123'),
        ).thenAnswer((_) async => existingHeadline);

        when(
          () => mockHeadlineRepository.delete(
            id: 'headline-123',
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async {});
      });

      test('returns 204 for admin user', () async {
        final response = await api.delete(
          '/api/v1/data/headline-123?model=headline',
          headers: {'Authorization': 'Bearer $adminToken'},
        );

        expect(response.statusCode, 204);
        verify(
          () => mockHeadlineRepository.delete(
            id: 'headline-123',
            userId: null,
          ),
        ).called(1);
      });

      test('returns 403 for standard user', () async {
        final response = await api.delete(
          '/api/v1/data/headline-123?model=headline',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 403);
        verifyNever(
          () => mockHeadlineRepository.delete(
            id: any(named: 'id'),
            userId: any(named: 'userId'),
          ),
        );
      });

      test('returns 401 for unauthenticated user', () async {
        final response = await api.delete(
          '/api/v1/data/headline-123?model=headline',
        );

        expect(response.statusCode, 401);
        verifyNever(
          () => mockHeadlineRepository.delete(
            id: any(named: 'id'),
            userId: any(named: 'userId'),
          ),
        );
      });
    });
  });
}
