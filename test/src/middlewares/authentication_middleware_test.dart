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

      // Reset capturedUser before each test
      setUp(() => capturedUser = null);
    });

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
      final context = createMockRequestContext(authenticatedUser: null);
      Response handler(context) => Response(body: 'should not be called');
      final middleware = requireAuthentication()(handler);

      expect(() => middleware(context), throwsA(isA<UnauthorizedException>()));
    });

    test('calls handler and provides non-nullable User when user exists', () {
      final user = createTestUser(id: 'user-id');
      final context = createMockRequestContext(authenticatedUser: user);
      Response handler(RequestContext context) {
        // Verify that the context now provides a non-nullable User
        expect(context.read<User>(), equals(user));
        return Response(body: 'ok');
      }

      final middleware = requireAuthentication()(handler);

      final response = middleware(context);
      expect(response, completion(isA<Response>()));
    });
  });
}
