import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/data_operation_registry.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../../routes/api/v1/data/[id]/_middleware.dart'
    as middleware;
import '../../../../../src/helpers/test_helpers.dart';

void main() {
  group('data item middleware', () {
    late Handler handler;
    late User standardUser;
    late Headline headline;
    late DataOperationRegistry mockRegistry;
    late PermissionService mockPermissionService;

    setUpAll(() {
      registerSharedFallbackValues();
      registerFallbackValue(createTestUser(id: 'fallback'));
    });

    setUp(() {
      handler = (context) => Response(body: 'ok');
      standardUser = createTestUser(id: 'user-id');
      headline = Headline(
        id: 'headline-id',
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
      mockRegistry = MockDataOperationRegistry();
      mockPermissionService = MockPermissionService();

      // Default stubs
      // PermissionService.isAdmin takes a positional User argument
      when(() => mockPermissionService.isAdmin(any())).thenReturn(false);
      when(
        () => mockRegistry.itemFetchers,
      ).thenReturn({
        'headline': (c, id) async => headline,
      });
    });

    test(
      'throws NotFoundException if dataFetchMiddleware fails to find item',
      () {
        // Mock fetcher to return null
        when(
          () => mockRegistry.itemFetchers,
        ).thenReturn({
          'headline': (c, id) async => null,
        });

        final context = createMockRequestContext(
          path: '/api/v1/data/non-existent-id',
          modelName: 'headline',
          dataOperationRegistry: mockRegistry,
          permissionService: mockPermissionService,
          authenticatedUser: standardUser,
          modelConfig: modelRegistry['headline'],
        );

        final composedMiddleware = middleware.middleware(handler);

        expect(
          () => composedMiddleware(context),
          throwsA(isA<NotFoundException>()),
        );
      },
    );

    test('throws ForbiddenException if ownershipCheckMiddleware fails', () {
      final otherUser = createTestUser(id: 'other-user-id');
      final userOwnedItem = AppSettings(
        id: 'owner-id',
        language: Language(
          id: 'en',
          code: 'en',
          name: 'English',
          nativeName: 'English',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
        ),
        displaySettings: const DisplaySettings(
          baseTheme: AppBaseTheme.system,
          accentTheme: AppAccentTheme.defaultBlue,
          fontFamily: 'SystemDefault',
          textScaleFactor: AppTextScaleFactor.medium,
          fontWeight: AppFontWeight.regular,
        ),
        feedSettings: const FeedSettings(
          feedItemDensity: FeedItemDensity.standard,
          feedItemImageStyle: FeedItemImageStyle.smallThumbnail,
          feedItemClickBehavior: FeedItemClickBehavior.defaultBehavior,
        ),
      );

      // Mock fetcher to return the user-owned item
      when(
        () => mockRegistry.itemFetchers,
      ).thenReturn({
        'app_settings': (c, id) async => userOwnedItem,
      });

      final context = createMockRequestContext(
        path: '/api/v1/data/owner-id',
        modelName: 'app_settings',
        dataOperationRegistry: mockRegistry,
        permissionService: mockPermissionService,
        authenticatedUser: otherUser, // Authenticated as someone else
        modelConfig: modelRegistry['app_settings'],
      );

      final composedMiddleware = middleware.middleware(handler);

      expect(
        () => composedMiddleware(context),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('calls handler when all checks pass', () async {
      final context = createMockRequestContext(
        path: '/api/v1/data/headline-id',
        modelName: 'headline',
        dataOperationRegistry: mockRegistry,
        permissionService: mockPermissionService,
        authenticatedUser: standardUser,
        modelConfig: modelRegistry['headline'],
      );

      final composedMiddleware = middleware.middleware(handler);
      final response = await composedMiddleware(context);

      expect(response.statusCode, equals(200));
      expect(await response.body(), equals('ok'));
    });
  });
}
