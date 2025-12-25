import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('ownershipCheckMiddleware', () {
    late PermissionService mockPermissionService;
    late Handler handler;
    late User ownerUser;
    late User otherUser;
    late User adminUser;
    late AppSettings userOwnedItem;

    setUpAll(registerSharedFallbackValues);

    setUp(() {
      mockPermissionService = MockPermissionService();
      handler = (context) => Response(body: 'ok');

      ownerUser = createTestUser(
        id: 'owner-id',
      );
      otherUser = createTestUser(
        id: 'other-id',
      );
      adminUser = createTestUser(
        id: 'admin-id',
        dashboardRole: DashboardUserRole.admin,
      );

      userOwnedItem = AppSettings(
        id: 'owner-id', // The item's ID is the owner's ID
        language: Language(
          id: 'lang-id',
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
          feedItemImageStyle: FeedItemImageStyle.largeThumbnail,
          feedItemClickBehavior: FeedItemClickBehavior.internalNavigation,
        ),
      );

      // Default stubs
      when(() => mockPermissionService.isAdmin(ownerUser)).thenReturn(false);
      when(() => mockPermissionService.isAdmin(otherUser)).thenReturn(false);
      when(() => mockPermissionService.isAdmin(adminUser)).thenReturn(true);
    });

    test('allows access when ownership check is not required', () async {
      final modelConfig = modelRegistry['headline']!;

      final context = createMockRequestContext(
        authenticatedUser: otherUser,
        modelConfig: modelConfig,
        modelName: 'headline',
        permissionService: mockPermissionService,
        fetchedItem: FetchedItem(userOwnedItem),
      );

      final middleware = ownershipCheckMiddleware()(handler);
      final response = await middleware(context);

      expect(await response.body(), 'ok');
    });

    test(
      'allows access for admin user even if ownership check is required',
      () async {
        final modelConfig = modelRegistry['app_settings']!;

        final context = createMockRequestContext(
          authenticatedUser: adminUser,
          modelConfig: modelConfig,
          modelName: 'app_settings',
          permissionService: mockPermissionService,
          fetchedItem: FetchedItem(userOwnedItem),
        );

        final middleware = ownershipCheckMiddleware()(handler);
        final response = await middleware(context);

        expect(await response.body(), 'ok');
      },
    );

    test('allows access when user is the owner', () async {
      final modelConfig = modelRegistry['app_settings']!;

      final context = createMockRequestContext(
        authenticatedUser: ownerUser,
        modelConfig: modelConfig,
        modelName: 'app_settings',
        permissionService: mockPermissionService,
        fetchedItem: FetchedItem(userOwnedItem),
      );

      final middleware = ownershipCheckMiddleware()(handler);
      final response = await middleware(context);

      expect(await response.body(), 'ok');
    });

    test('throws ForbiddenException when user is not the owner', () {
      final modelConfig = modelRegistry['app_settings']!;

      final context = createMockRequestContext(
        authenticatedUser: otherUser, // A different user
        modelConfig: modelConfig,
        modelName: 'app_settings',
        permissionService: mockPermissionService,
        fetchedItem: FetchedItem(userOwnedItem),
      );

      final middleware = ownershipCheckMiddleware()(handler);

      expect(() => middleware(context), throwsA(isA<ForbiddenException>()));
    });

    test(
      'throws OperationFailedException if ownership check is required but getOwnerId is not configured',
      () {
        // Create a faulty config
        final faultyConfig = ModelConfig<Headline>(
          fromJson: Headline.fromJson,
          getId: (h) => h.id,
          getOwnerId: null, // Missing getOwnerId
          getItemPermission: const ModelActionPermission(
            type: RequiredPermissionType.specificPermission,
            permission: 'test.read',
            requiresOwnershipCheck: true, // But check is required
          ),
          getCollectionPermission: const ModelActionPermission(
            type: RequiredPermissionType.none,
          ),
          postPermission: const ModelActionPermission(
            type: RequiredPermissionType.none,
          ),
          putPermission: const ModelActionPermission(
            type: RequiredPermissionType.none,
          ),
          deletePermission: const ModelActionPermission(
            type: RequiredPermissionType.none,
          ),
        );

        final context = createMockRequestContext(
          authenticatedUser: ownerUser,
          modelConfig: faultyConfig,
          modelName: 'faulty_model',
          permissionService: mockPermissionService,
          fetchedItem: FetchedItem(userOwnedItem),
        );

        final middleware = ownershipCheckMiddleware()(handler);

        expect(
          () => middleware(context),
          throwsA(isA<OperationFailedException>()),
        );
      },
    );
  });
}
