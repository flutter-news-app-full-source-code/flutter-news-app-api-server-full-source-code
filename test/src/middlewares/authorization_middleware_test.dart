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
      registerSharedFallbackValues();
      registerFallbackValue(createTestUser(id: 'fallback-user'));
    });

    setUp(() {
      mockPermissionService = MockPermissionService();
      handler = (context) => Response(body: 'ok');
      standardUser = User(
        id: 'user-id',
        email: 'test@example.com',
        role: UserRole.user,
        tier: AccessTier.standard,
        createdAt: DateTime.now(),
      );
      adminUser = standardUser.copyWith(role: UserRole.admin);

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
            requiresAuthentication: true,
          ),
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

        // We need to ensure context.read<User?>() returns null.
        // createMockRequestContext doesn't provide User? if null.
        // So we manually mock the context for this specific case to ensure control.
        final context = MockRequestContext();
        final request = MockRequest();
        final uri = Uri.parse('http://localhost/api/v1/data');
        when(() => context.request).thenReturn(request);
        when(() => request.method).thenReturn(HttpMethod.get);
        when(() => request.uri).thenReturn(uri);
        when(() => context.read<User?>()).thenReturn(null);
        when(() => context.read<String>()).thenReturn('headline');
        when(
          () => context.read<ModelConfig<dynamic>>(),
        ).thenReturn(modelConfig);
        when(
          () => context.read<PermissionService>(),
        ).thenReturn(mockPermissionService);

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
            requiresAuthentication: false,
          ),
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

        // Manually mock for null user scenario
        final context = MockRequestContext();
        final request = MockRequest();
        final uri = Uri.parse('http://localhost/api/v1/data/some-id');
        when(() => context.request).thenReturn(request);
        when(() => request.method).thenReturn(HttpMethod.get);
        when(() => request.uri).thenReturn(uri);
        when(() => context.read<User?>()).thenReturn(null);
        when(() => context.read<String>()).thenReturn('remote_config');
        when(
          () => context.read<ModelConfig<dynamic>>(),
        ).thenReturn(modelConfig);
        when(
          () => context.read<PermissionService>(),
        ).thenReturn(mockPermissionService);

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
      ).thenReturn(false);

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
        modelConfig: modelRegistry['headline'],
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
        modelConfig: modelRegistry['language'],
        modelName: 'language',
        permissionService: mockPermissionService,
        path: '/api/v1/data',
      );

      final middleware = authorizationMiddleware()(handler);

      expect(() => middleware(context), throwsA(isA<ForbiddenException>()));
    });
  });
}
