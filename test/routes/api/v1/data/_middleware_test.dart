import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/rate_limit_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../routes/api/v1/data/_middleware.dart' as middleware;
import '../../../../src/helpers/test_helpers.dart';

class MockHttpConnectionInfo extends Mock implements HttpConnectionInfo {}

void main() {
  group('data route middleware', () {
    late Handler handler;
    late User standardUser;
    late ModelRegistryMap modelRegistryMap;
    late PermissionService mockPermissionService;
    late RateLimitService mockRateLimitService;

    setUpAll(() {
      registerSharedFallbackValues();
      registerFallbackValue(createTestUser(id: 'fallback-user'));
    });

    setUp(() {
      handler = (context) => Response(body: 'ok');
      standardUser = createTestUser(id: 'user-id');
      modelRegistryMap = modelRegistry;
      mockPermissionService = MockPermissionService();
      mockRateLimitService = MockRateLimitService();

      // PermissionService.hasPermission takes positional arguments (User, String)
      when(
        () => mockPermissionService.hasPermission(any(), any()),
      ).thenReturn(true);
      // Ensure isAdmin returns false by default to avoid Null boolean errors
      when(() => mockPermissionService.isAdmin(any())).thenReturn(false);

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
      );
      // Note: createMockRequestContext already provides ModelRegistryMap.
      // We don't need to provide it again unless we want to override it.

      final composedMiddleware = middleware.middleware(handler);

      expect(
        () => composedMiddleware(context),
        throwsA(isA<BadRequestException>()),
      );
    });

    test('throws UnauthorizedException if auth is required and user is not '
        'provided', () {
      // 'headline' GET collection requires authentication.
      // We use createMockRequestContext but explicitly do NOT provide an authenticatedUser.
      // This simulates an unauthenticated request.

      final context = createMockRequestContext(
        queryParams: {'model': 'headline'},
        // authenticatedUser is null by default
        permissionService: mockPermissionService,
        rateLimitService: mockRateLimitService,
      );

      // We need to ensure the IP extraction works for unauthenticated rate limiting
      // or bypass it. createMockRequestContext sets up a basic request.
      // However, _dataRateLimiterMiddleware tries to get IP if user is null.
      // The TestRequestContext request might not have connectionInfo.
      // But wait, _conditionalAuthenticationMiddleware runs BEFORE rate limiter.
      // It checks permissions. If auth is required and missing, it throws UnauthorizedException.
      // So rate limiter is never reached.

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
      );

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
      );

      final composedMiddleware = middleware.middleware(handler);
      final response = await composedMiddleware(context);

      expect(response.statusCode, equals(200));
      expect(await response.body(), equals('ok'));
    });

    test('allows public access when configured', () async {
      // 'remote_config' GET item does not require authentication

      // Mock the request and connection info to avoid Null check operator error
      final mockRequest = MockRequest();
      final mockConnectionInfo = MockHttpConnectionInfo();
      final uri = Uri.parse(
        'http://localhost/api/v1/data/some-id?model=remote_config',
      );

      when(
        () => mockConnectionInfo.remoteAddress,
      ).thenReturn(InternetAddress.loopbackIPv4);
      when(() => mockRequest.connectionInfo).thenReturn(mockConnectionInfo);
      when(() => mockRequest.method).thenReturn(HttpMethod.get);
      when(() => mockRequest.uri).thenReturn(uri);
      when(() => mockRequest.headers).thenReturn({});

      // We need to ensure the context uses this mock request.
      // createMockRequestContext helper creates a TestRequestContext which creates its own Request.
      // We need to pass our mock request to it.

      final context = createMockRequestContext(
        request: mockRequest,
        path: '/api/v1/data/some-id',
        queryParams: {'model': 'remote_config'},
        // No authenticated user
        permissionService: mockPermissionService,
        rateLimitService: mockRateLimitService,
      );

      final composedMiddleware = middleware.middleware(handler);
      final response = await composedMiddleware(context);

      expect(response.statusCode, equals(200));
      expect(await response.body(), equals('ok'));
    });
  });
}
