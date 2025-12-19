import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/data_fetch_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/data_operation_registry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('dataFetchMiddleware', () {
    late DataOperationRegistry mockRegistry;
    late Handler handler;
    late Headline headline;
    FetchedItem<dynamic>? capturedItem;

    setUp(() {
      mockRegistry = MockDataOperationRegistry();
      headline = Headline(
        id: 'headline-id',
        title: 'Test Headline',
        url: 'http://example.com',
        imageUrl: 'http://example.com/image.png',
        source: Source(
          id: 'source-id',
          name: 'Test Source',
          description: '',
          url: '',
          logoUrl: '',
          sourceType: SourceType.other,
          language: Language(
            id: 'lang-id',
            code: 'en',
            name: 'English',
            nativeName: 'English',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
          headquarters: Country(
            id: 'country-id',
            isoCode: 'US',
            name: 'United States',
            flagUrl: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
        ),
        eventCountry: Country(
          id: 'country-id',
          isoCode: 'US',
          name: 'United States',
          flagUrl: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
        ),
        topic: Topic(
          id: 'topic-id',
          name: 'Test Topic',
          description: '',
          iconUrl: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
        isBreaking: false,
      );

      handler = (context) {
        capturedItem = context.read<FetchedItem<dynamic>>();
        return Response(body: 'ok');
      };

      // Reset captured item before each test
      setUp(() => capturedItem = null);
    });

    test('fetches item and provides it to context', () async {
      const modelName = 'headline';
      const itemId = 'headline-id';

      // Mock the fetcher function
      Future<Headline> fetcher(RequestContext context, String id) async =>
          headline;
      when(() => mockRegistry.itemFetchers).thenReturn({modelName: fetcher});

      final context = createMockRequestContext(
        path: '/api/v1/data/$itemId',
        modelName: modelName,
        dataOperationRegistry: mockRegistry,
      );

      final middleware = dataFetchMiddleware()(handler);
      await middleware(context);

      expect(capturedItem, isNotNull);
      expect(capturedItem, isA<FetchedItem<dynamic>>());
      expect(capturedItem!.data, equals(headline));
    });

    test('throws NotFoundException when item is not found', () {
      const modelName = 'headline';
      const itemId = 'non-existent-id';

      // Mock the fetcher to return null
      Future<Null> fetcher(RequestContext context, String id) async => null;
      when(() => mockRegistry.itemFetchers).thenReturn({modelName: fetcher});

      final context = createMockRequestContext(
        path: '/api/v1/data/$itemId',
        modelName: modelName,
        dataOperationRegistry: mockRegistry,
      );

      final middleware = dataFetchMiddleware()(handler);

      expect(() => middleware(context), throwsA(isA<NotFoundException>()));
    });

    test('throws OperationFailedException for unsupported model', () {
      const modelName = 'unsupported-model';
      const itemId = 'some-id';

      // No fetcher registered for this model
      when(() => mockRegistry.itemFetchers).thenReturn({});

      final context = createMockRequestContext(
        path: '/api/v1/data/$itemId',
        modelName: modelName,
        dataOperationRegistry: mockRegistry,
      );

      final middleware = dataFetchMiddleware()(handler);

      expect(
        () => middleware(context),
        throwsA(isA<OperationFailedException>()),
      );
    });
  });
}
