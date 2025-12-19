import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('authorizationMiddleware', () {
    late PermissionService mockPermissionService;
    late Handler handler;
    late User standardUser;
    late User adminUser;

    setUpAll(() {
      registerFallbackValue(createTestUser(id: 'fallback-user'));
    });

    setUp(() {
      mockPermissionService = MockPermissionService();
      handler = (context) => Response(body: 'ok');
      standardUser = User(
        id: 'user-id',
        email: 'test@example.com',
        appRole: AppUserRole.standardUser,
        dashboardRole: DashboardUserRole.none,
        feedDecoratorStatus: const {},
        createdAt: DateTime.now(),
      );
      adminUser = standardUser.copyWith(dashboardRole: DashboardUserRole.admin);

      // Default stubs
      when(
        () => mockPermissionService.hasPermission(any(), any()),
      ).thenReturn(false);
      when(() => mockPermissionService.isAdmin(any())).thenReturn(false);
      when(() => mockPermissionService.isAdmin(adminUser)).thenReturn(true);
    });

    test(
      'throws UnauthorizedException if auth is required but user is null',
      () {
        final modelConfig = ModelConfig<Headline>(
          fromJson: Headline.fromJson,
          getId: (h) => h.id,
          getCollectionPermission: const ModelActionPermission(
            type: RequiredPermissionType.specificPermission,
            permission: Permissions.headlineRead,
            requiresAuthentication: true, // This is key
          ),
          // Other permissions don't matter for this test
          getItemPermission: const ModelActionPermission(
            type: RequiredPermissionType.unsupported,
          ),
          postPermission: const ModelActionPermission(
            type: RequiredPermissionType.unsupported,
          ),
          putPermission: const ModelActionPermission(
            type: RequiredPermissionType.unsupported,
          ),
          deletePermission: const ModelActionPermission(
            type: RequiredPermissionType.unsupported,
          ),
        );

        final context = createMockRequestContext(
          authenticatedUser: null, // No user
          modelConfig: modelConfig,
          modelName: 'headline',
          permissionService: mockPermissionService,
          path: '/api/v1/data',
        );

        final middleware = authorizationMiddleware()(handler);

        expect(
          () => middleware(context),
          throwsA(isA<UnauthorizedException>()),
        );
      },
    );

    test(
      'allows access for public route (requiresAuthentication: false)',
      () async {
        final modelConfig = ModelConfig<RemoteConfig>(
          fromJson: RemoteConfig.fromJson,
          getId: (rc) => rc.id,
          getItemPermission: const ModelActionPermission(
            type: RequiredPermissionType.none,
            requiresAuthentication: false, // Publicly accessible
          ),
          // Other permissions
          getCollectionPermission: const ModelActionPermission(
            type: RequiredPermissionType.unsupported,
          ),
          postPermission: const ModelActionPermission(
            type: RequiredPermissionType.unsupported,
          ),
          putPermission: const ModelActionPermission(
            type: RequiredPermissionType.unsupported,
          ),
          deletePermission: const ModelActionPermission(
            type: RequiredPermissionType.unsupported,
          ),
        );

        final context = createMockRequestContext(
          authenticatedUser: null, // No user
          modelConfig: modelConfig,
          modelName: 'remote_config',
          permissionService: mockPermissionService,
          path: '/api/v1/data/some-id',
        );

        final middleware = authorizationMiddleware()(handler);
        final response = await middleware(context);

        expect(await response.body(), 'ok');
      },
    );

    test('allows access when user has specific permission', () async {
      when(
        () => mockPermissionService.hasPermission(
          standardUser,
          Permissions.headlineRead,
        ),
      ).thenReturn(true);

      final context = createMockRequestContext(
        authenticatedUser: standardUser,
        modelConfig: modelRegistry['headline'],
        modelName: 'headline',
        permissionService: mockPermissionService,
        path: '/api/v1/data',
      );

      final middleware = authorizationMiddleware()(handler);
      final response = await middleware(context);

      expect(await response.body(), 'ok');
    });

    test('throws ForbiddenException when user lacks specific permission', () {
      when(
        () => mockPermissionService.hasPermission(
          standardUser,
          Permissions.headlineCreate,
        ),
      ).thenReturn(false); // User cannot create

      final context = createMockRequestContext(
        method: HttpMethod.post,
        authenticatedUser: standardUser,
        modelConfig: modelRegistry['headline'],
        modelName: 'headline',
        permissionService: mockPermissionService,
        path: '/api/v1/data',
      );

      final middleware = authorizationMiddleware()(handler);

      expect(() => middleware(context), throwsA(isA<ForbiddenException>()));
    });

    test('allows admin access for adminOnly permission type', () async {
      final context = createMockRequestContext(
        method: HttpMethod.post,
        authenticatedUser: adminUser,
        modelConfig: modelRegistry['headline'], // post is adminOnly
        modelName: 'headline',
        permissionService: mockPermissionService,
        path: '/api/v1/data',
      );

      final middleware = authorizationMiddleware()(handler);
      final response = await middleware(context);

      expect(await response.body(), 'ok');
    });

    test('throws ForbiddenException for unsupported action type', () {
      final context = createMockRequestContext(
        method: HttpMethod.post,
        authenticatedUser: adminUser,
        modelConfig: modelRegistry['language'], // post is unsupported
        modelName: 'language',
        permissionService: mockPermissionService,
        path: '/api/v1/data',
      );

      final middleware = authorizationMiddleware()(handler);

      expect(() => middleware(context), throwsA(isA<ForbiddenException>()));
    });
  });
}
