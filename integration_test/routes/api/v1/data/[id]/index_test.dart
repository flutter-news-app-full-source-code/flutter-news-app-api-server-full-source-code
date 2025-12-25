import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/data_operation_registry.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../../routes/api/v1/data/[id]/index.dart' as route;
import '../../../../../../test/src/helpers/test_helpers.dart';

void main() {
  group('/api/v1/data/[id] (item)', () {
    late DataOperationRegistry mockRegistry;
    late User standardUser;
    late Headline headline;
    const headlineId = 'headline-id';

    setUpAll(() {
      registerSharedFallbackValues();
      registerFallbackValue(MockRequestContext());
      registerFallbackValue(createTestUser(id: 'fallback'));
    });

    setUp(() {
      mockRegistry = MockDataOperationRegistry();
      standardUser = createTestUser(id: 'user-id');
      headline = Headline(
        id: headlineId,
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
    });

    group('GET', () {
      test('returns item from context provided by middleware', () async {
        final context = createMockRequestContext(
          method: HttpMethod.get,
          modelName: 'headline',
          fetchedItem: FetchedItem(headline), // Pre-fetched by middleware
        );

        final response = await route.onRequest(context, headlineId);

        expect(response.statusCode, equals(200));
        final body = await response.json() as Map<String, dynamic>;
        expect(body['data']['id'], equals(headlineId));
      });
    });

    group('PUT', () {
      test('calls correct updater and returns updated item', () async {
        final updatedHeadline = headline.copyWith(title: 'Updated Title');
        final requestBody = updatedHeadline.toJson();

        Future<Headline> updater(
          RequestContext c,
          String id,
          dynamic item,
          String? uid,
        ) async => updatedHeadline;
        when(() => mockRegistry.itemUpdaters).thenReturn({'headline': updater});

        final context = createMockRequestContext(
          method: HttpMethod.put,
          modelName: 'headline',
          modelConfig: modelRegistry['headline'],
          authenticatedUser: standardUser,
          dataOperationRegistry: mockRegistry,
          permissionService: MockPermissionService(),
          body: requestBody,
        );

        final response = await route.onRequest(context, headlineId);

        expect(response.statusCode, equals(200));
        final body = await response.json() as Map<String, dynamic>;
        expect(body['data']['title'], equals('Updated Title'));
      });

      test('throws BadRequestException for missing body', () async {
        final context = createMockRequestContext(
          method: HttpMethod.put,
          modelName: 'headline',
          modelConfig: modelRegistry['headline'],
          authenticatedUser: standardUser,
          dataOperationRegistry: mockRegistry,
          permissionService: MockPermissionService(),
          body: null,
        );

        expect(
          () => route.onRequest(context, headlineId),
          throwsA(isA<BadRequestException>()),
        );
      });

      test('throws BadRequestException for ID mismatch in body', () async {
        final requestBody = headline.copyWith(id: 'different-id').toJson();

        final context = createMockRequestContext(
          method: HttpMethod.put,
          modelName: 'headline',
          modelConfig: modelRegistry['headline'],
          authenticatedUser: standardUser,
          dataOperationRegistry: mockRegistry,
          permissionService: MockPermissionService(),
          body: requestBody,
        );

        expect(
          () => route.onRequest(context, headlineId),
          throwsA(isA<BadRequestException>()),
        );
      });
    });

    group('DELETE', () {
      test('calls correct deleter and returns 204', () async {
        Future<Type> deleter(RequestContext c, String id, String? uid) async =>
            Future<void>;
        when(() => mockRegistry.itemDeleters).thenReturn({'headline': deleter});

        final context = createMockRequestContext(
          method: HttpMethod.delete,
          modelName: 'headline',
          modelConfig: modelRegistry['headline'],
          authenticatedUser: standardUser,
          dataOperationRegistry: mockRegistry,
          permissionService: MockPermissionService(),
        );

        final response = await route.onRequest(context, headlineId);

        expect(response.statusCode, equals(204));
      });
    });

    test('returns 405 for unsupported method', () async {
      final context = createMockRequestContext(method: HttpMethod.patch);
      final response = await route.onRequest(context, headlineId);
      expect(response.statusCode, equals(405));
    });
  });
}
