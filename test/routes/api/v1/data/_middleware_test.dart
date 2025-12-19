import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/rate_limit_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../routes/api/v1/data/_middleware.dart' as middleware;
import '../../../../src/helpers/test_helpers.dart';

void main() {
  group('data route middleware', () {
    late Handler handler;
    late User standardUser;
    late ModelRegistryMap modelRegistryMap;
    late PermissionService mockPermissionService;
    late RateLimitService mockRateLimitService;

    setUpAll(() {
      registerFallbackValue(createTestUser(id: 'fallback-user'));
    });

    setUp(() {
      handler = (context) => Response(body: 'ok');
      standardUser = createTestUser(id: 'user-id');
      modelRegistryMap = modelRegistry;
      mockPermissionService = MockPermissionService();
      mockRateLimitService = MockRateLimitService();

      when(
        () => mockPermissionService.hasPermission(any(), any()),
      ).thenReturn(true);
      when(
        () => mockRateLimitService.checkRequest(
          key: any(named: 'key'),
          limit: any(named: 'limit'),
          window: any(named: 'window'),
        ),
      ).thenAnswer((_) async {});
    });

    test('throws BadRequestException if model parameter is missing', () {
      final context = createMockRequestContext(queryParams: {});
      final composedMiddleware = middleware.middleware(handler);

      expect(
        () => composedMiddleware(context),
        throwsA(isA<BadRequestException>()),
      );
    });

    test('throws BadRequestException if model is invalid', () {
      final context = createMockRequestContext(
        queryParams: {'model': 'invalid_model'},
      ).provide<ModelRegistryMap>(() => modelRegistryMap);

      final composedMiddleware = middleware.middleware(handler);

      expect(
        () => composedMiddleware(context),
        throwsA(isA<BadRequestException>()),
      );
    });

    test('throws UnauthorizedException if auth is required and user is not '
        'provided', () {
      // 'headline' GET collection requires authentication
      final context = createMockRequestContext(
        queryParams: {'model': 'headline'},
        authenticatedUser: null,
        permissionService: mockPermissionService,
      ).provide<ModelRegistryMap>(() => modelRegistryMap);

      final composedMiddleware = middleware.middleware(handler);

      expect(
        () => composedMiddleware(context),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('throws ForbiddenException if user lacks permission', () {
      // User does not have permission to create headlines
      when(
        () => mockPermissionService.hasPermission(any(), any()),
      ).thenReturn(false);

      final context = createMockRequestContext(
        method: HttpMethod.post,
        queryParams: {'model': 'headline'},
        authenticatedUser: standardUser,
        permissionService: mockPermissionService,
        rateLimitService: mockRateLimitService,
      ).provide<ModelRegistryMap>(() => modelRegistryMap);

      final composedMiddleware = middleware.middleware(handler);

      expect(
        () => composedMiddleware(context),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('calls handler when all checks pass', () async {
      // 'headline' GET collection requires auth and a specific permission
      final context = createMockRequestContext(
        queryParams: {'model': 'headline'},
        authenticatedUser: standardUser,
        permissionService: mockPermissionService,
        rateLimitService: mockRateLimitService,
      ).provide<ModelRegistryMap>(() => modelRegistryMap);

      final composedMiddleware = middleware.middleware(handler);
      final response = await composedMiddleware(context);

      expect(response.statusCode, equals(200));
      expect(await response.body(), equals('ok'));
    });

    test('allows public access when configured', () async {
      // 'remote_config' GET item does not require authentication
      final context = createMockRequestContext(
        queryParams: {'model': 'remote_config'},
        authenticatedUser: null, // No user
        permissionService: mockPermissionService,
        rateLimitService: mockRateLimitService,
        path: '/api/v1/data/some-id', // Simulate item request
      ).provide<ModelRegistryMap>(() => modelRegistryMap);

      final composedMiddleware = middleware.middleware(handler);
      final response = await composedMiddleware(context);

      expect(response.statusCode, equals(200));
      expect(await response.body(), equals('ok'));
    });
  });
}
