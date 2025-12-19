import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/data_operation_registry.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../routes/api/v1/data/index.dart' as route;
import '../../../../src/helpers/test_helpers.dart';

void main() {
  group('/api/v1/data (collection)', () {
    late DataOperationRegistry mockRegistry;
    late User standardUser;

    setUpAll(() {
      registerFallbackValue(MockRequestContext());
    });

    setUp(() {
      mockRegistry = MockDataOperationRegistry();
      standardUser = createTestUser(id: 'user-id');
    });

    group('GET', () {
      test('calls correct reader with all parameters', () async {
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

        final paginatedResponse = PaginatedResponse<Headline>(
          items: [headline],
          cursor: 'next',
          hasMore: true,
        );

        Future<PaginatedResponse<Headline>> reader(
          RequestContext c,
          String? uid,
          Map<String, dynamic>? f,
          List<SortOption>? s,
          PaginationOptions? p,
        ) async => paginatedResponse;

        when(
          () => mockRegistry.allItemsReaders,
        ).thenReturn({'headline': reader});

        final context = createMockRequestContext(
          method: HttpMethod.get,
          modelName: 'headline',
          modelConfig: modelRegistry['headline'],
          authenticatedUser: standardUser,
          dataOperationRegistry: mockRegistry,
          permissionService: MockPermissionService(),
          queryParams: {
            'filter': '{"key":"value"}',
            'sort': 'createdAt:desc',
            'limit': '10',
            'cursor': 'start',
          },
        );

        final response = await route.onRequest(context);

        expect(response.statusCode, equals(200));
        final body = await response.json() as Map<String, dynamic>;
        expect(body['data']['items'], isA<List<dynamic>>());
      });

      test('throws BadRequestException for invalid filter JSON', () async {
        final context = createMockRequestContext(
          method: HttpMethod.get,
          modelName: 'headline',
          modelConfig: modelRegistry['headline'],
          authenticatedUser: standardUser,
          dataOperationRegistry: mockRegistry,
          permissionService: MockPermissionService(),
          queryParams: {'filter': '{"key":value}'}, // Invalid JSON
        );

        expect(
          () => route.onRequest(context),
          throwsA(isA<BadRequestException>()),
        );
      });
    });

    group('POST', () {
      late Headline headline;

      setUp(() {
        headline = Headline(
          id: 'new-id',
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
        Future<Headline> creator(
          RequestContext c,
          dynamic item,
          String? uid,
        ) async => headline.copyWith(id: (item as Headline).id);
        when(() => mockRegistry.itemCreators).thenReturn({'headline': creator});
      });

      test('calls correct creator and returns 201', () async {
        final requestBody = headline.toJson()..remove('id');

        final context = createMockRequestContext(
          method: HttpMethod.post,
          modelName: 'headline',
          modelConfig: modelRegistry['headline'],
          authenticatedUser: standardUser,
          dataOperationRegistry: mockRegistry,
          permissionService: MockPermissionService(),
          body: requestBody,
        );

        final response = await route.onRequest(context);

        expect(response.statusCode, equals(201));
        final body = await response.json() as Map<String, dynamic>;
        expect(body['data']['id'], isA<String>());
        expect(body['data']['title'], equals(headline.title));
      });

      test('throws BadRequestException for missing body', () async {
        final context = createMockRequestContext(
          method: HttpMethod.post,
          modelName: 'headline',
          modelConfig: modelRegistry['headline'],
          authenticatedUser: standardUser,
          dataOperationRegistry: mockRegistry,
          permissionService: MockPermissionService(),
          body: null,
        );

        expect(
          () => route.onRequest(context),
          throwsA(isA<BadRequestException>()),
        );
      });

      test('throws BadRequestException for invalid body (TypeError)', () async {
        final context = createMockRequestContext(
          method: HttpMethod.post,
          modelName: 'headline',
          modelConfig: modelRegistry['headline'],
          authenticatedUser: standardUser,
          dataOperationRegistry: mockRegistry,
          permissionService: MockPermissionService(),
          body: {'invalid_field': 'value'}, // Missing required fields
        );

        expect(
          () => route.onRequest(context),
          throwsA(isA<BadRequestException>()),
        );
      });
    });
  });
}
