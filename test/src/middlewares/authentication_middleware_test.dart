import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('authenticationProvider', () {
    late AuthTokenService mockAuthTokenService;
    late Handler handler;
    late User user;
    User? capturedUser;

    setUpAll(registerSharedFallbackValues);

    setUp(() {
      mockAuthTokenService = MockAuthTokenService();
      user = User(
        id: 'user-id',
        email: 'test@example.com',
        appRole: AppUserRole.standardUser,
        dashboardRole: DashboardUserRole.none,
        feedDecoratorStatus: const {},
        createdAt: DateTime.now(),
      );

      // A simple handler that captures the provided User?
      handler = (context) {
        capturedUser = context.read<User?>();
        return Response(body: 'ok');
      };
    });

    // Reset capturedUser before each test
    setUp(() => capturedUser = null);

    test('provides user when token is valid', () async {
      const token = 'valid-token';
      when(
        () => mockAuthTokenService.validateToken(token),
      ).thenAnswer((_) async => user);

      final context = createMockRequestContext(
        headers: {'Authorization': 'Bearer $token'},
        authTokenService: mockAuthTokenService,
      );

      final middleware = authenticationProvider()(handler);
      await middleware(context);

      expect(capturedUser, equals(user));
    });

    test('provides null when token is invalid', () async {
      const token = 'invalid-token';
      when(
        () => mockAuthTokenService.validateToken(token),
      ).thenAnswer((_) async => null);

      final context = createMockRequestContext(
        headers: {'Authorization': 'Bearer $token'},
        authTokenService: mockAuthTokenService,
      );

      final middleware = authenticationProvider()(handler);
      await middleware(context);

      expect(capturedUser, isNull);
    });

    test('provides null when token validation throws HttpException', () async {
      const token = 'expired-token';
      when(
        () => mockAuthTokenService.validateToken(token),
      ).thenThrow(const UnauthorizedException('Token expired'));

      final context = createMockRequestContext(
        headers: {'Authorization': 'Bearer $token'},
        authTokenService: mockAuthTokenService,
      );

      final middleware = authenticationProvider()(handler);
      await middleware(context);

      expect(capturedUser, isNull);
    });

    test('provides null when Authorization header is missing', () async {
      final context = createMockRequestContext(
        authTokenService: mockAuthTokenService,
      );

      final middleware = authenticationProvider()(handler);
      await middleware(context);

      expect(capturedUser, isNull);
      verifyNever(() => mockAuthTokenService.validateToken(any()));
    });

    test('provides null when Authorization header is malformed', () async {
      final context = createMockRequestContext(
        headers: {'Authorization': 'invalid-header'},
        authTokenService: mockAuthTokenService,
      );

      final middleware = authenticationProvider()(handler);
      await middleware(context);

      expect(capturedUser, isNull);
      verifyNever(() => mockAuthTokenService.validateToken(any()));
    });
  });

  group('requireAuthentication', () {
    test('throws UnauthorizedException when user is null', () {
      // We explicitly pass authenticatedUser: null, but createMockRequestContext
      // doesn't provide User? if it's null.
      // However, TestRequestContext mocks read<User?> to return null by default if not provided?
      // No, mocktail throws if not stubbed.
      // We need to ensure context.read<User?>() returns null.
      // createMockRequestContext doesn't provide it if null.
      // But requireAuthentication calls context.read<User?>().
      // We must provide it as null.
      // Since createMockRequestContext helper logic is:
      // if (authenticatedUser != null) { provide... }
      // We need to manually stub it or update helper.
      // Actually, dart_frog_test's TestRequestContext might not support providing null easily via helper.
      // Let's rely on the fact that if we don't provide it, read<User?> might throw or return null depending on implementation.
      // But wait, requireAuthentication reads User?.
      // Let's update the test to use a context where we know User? is null.
      // The helper doesn't provide it if null.
      // So we need to manually provide null or let it fail?
      // Actually, let's just use the helper. If it fails, we fix the helper.
      // In dart_frog, reading a non-existent provider throws StateError.
      // But `authenticationProvider` provides `User?` (nullable).
      // If `authenticationProvider` ran before `requireAuthentication`, `User?` would be in context (as null).
      // Here we are testing `requireAuthentication` in isolation.
      // We should assume `User?` is provided.

      // We can't use createMockRequestContext to provide null easily with current logic.
      // Let's just use a raw TestRequestContext here or modify helper.
      // Easier: modify helper to allow providing null explicitly?
      // Or just assume the middleware stack usually has authenticationProvider.
      // For this unit test, we can just mock it.

      final context = MockRequestContext();
      when(() => context.read<User?>()).thenReturn(null);

      Response handler(RequestContext context) =>
          Response(body: 'should not be called');
      final middleware = requireAuthentication()(handler);

      expect(() => middleware(context), throwsA(isA<UnauthorizedException>()));
    });

    test(
      'calls handler and provides non-nullable User when user exists',
      () async {
        final user = createTestUser(id: 'user-id');
        final context = createMockRequestContext(authenticatedUser: user);
        Response handler(RequestContext context) {
          // Verify that the context now provides a non-nullable User
          expect(context.read<User>(), equals(user));
          return Response(body: 'ok');
        }

        final middleware = requireAuthentication()(handler);
        final response = await middleware(context);
        expect(response, isA<Response>());
      },
    );
  });
}
