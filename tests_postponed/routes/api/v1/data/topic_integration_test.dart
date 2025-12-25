import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../test/src/helpers/test_helpers.dart';
import 'test_api.dart';

void main() {
  group('Topic Integration Tests', () {
    late TestApi api;
    late MockDataRepository<Topic> mockRepo;
    late MockAuthTokenService mockAuthTokenService;

    late User adminUser;
    late User standardUser;
    late String adminToken;
    late String standardToken;

    late Topic topic;

    setUpAll(() {
      registerSharedFallbackValues();
      registerFallbackValue(const PaginationOptions());
      registerFallbackValue(const SortOption('createdAt'));
      registerFallbackValue(
        Topic(
          id: 'fallback-id',
          name: 'Fallback Topic',
          description: 'Fallback Description',
          iconUrl: 'http://fallback.com/icon.png',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
        ),
      );
    });

    setUp(() {
      mockRepo = MockDataRepository<Topic>();
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

      topic = Topic(
        id: 'topic-1',
        name: 'Technology',
        description: 'Tech news',
        iconUrl: 'url',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      );

      api = TestApi.from(
        (context) => context
            .provide<DataRepository<Topic>>(() => mockRepo)
            .provide<AuthTokenService>(() => mockAuthTokenService),
      );
    });

    group('GET /api/v1/data?model=topic', () {
      test('returns 200 for standard user', () async {
        when(
          () => mockRepo.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [topic],
            cursor: null,
            hasMore: false,
          ),
        );

        final response = await api.get(
          '/api/v1/data?model=topic',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 200);
      });
    });

    group('POST /api/v1/data?model=topic', () {
      test('returns 201 for admin user', () async {
        when(
          () => mockRepo.create(
            item: any(named: 'item'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (invocation) async => invocation.namedArguments[#item] as Topic,
        );

        final response = await api.post(
          '/api/v1/data?model=topic',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(topic.toJson()),
        );

        expect(response.statusCode, 201);
      });

      test('returns 403 for standard user', () async {
        final response = await api.post(
          '/api/v1/data?model=topic',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(topic.toJson()),
        );

        expect(response.statusCode, 403);
      });
    });

    group('PUT /api/v1/data/:id?model=topic', () {
      setUp(() {
        when(() => mockRepo.read(id: topic.id)).thenAnswer((_) async => topic);
      });

      test('returns 200 for admin user', () async {
        final updatedTopic = topic.copyWith(name: 'Updated Tech');
        when(
          () => mockRepo.update(
            id: topic.id,
            item: any(named: 'item'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => updatedTopic);

        final response = await api.put(
          '/api/v1/data/${topic.id}?model=topic',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(updatedTopic.toJson()),
        );

        expect(response.statusCode, 200);
      });

      test('returns 403 for standard user', () async {
        final response = await api.put(
          '/api/v1/data/${topic.id}?model=topic',
          headers: {'Authorization': 'Bearer $standardToken'},
          body: jsonEncode(topic.toJson()),
        );

        expect(response.statusCode, 403);
      });
    });

    group('DELETE /api/v1/data/:id?model=topic', () {
      setUp(() {
        when(() => mockRepo.read(id: topic.id)).thenAnswer((_) async => topic);
        when(
          () => mockRepo.delete(
            id: topic.id,
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async {});
      });

      test('returns 204 for admin user', () async {
        final response = await api.delete(
          '/api/v1/data/${topic.id}?model=topic',
          headers: {'Authorization': 'Bearer $adminToken'},
        );

        expect(response.statusCode, 204);
      });

      test('returns 403 for standard user', () async {
        final response = await api.delete(
          '/api/v1/data/${topic.id}?model=topic',
          headers: {'Authorization': 'Bearer $standardToken'},
        );

        expect(response.statusCode, 403);
      });
    });
  });
}
