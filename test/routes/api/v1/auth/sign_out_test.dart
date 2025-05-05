import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// Import the actual route handler
import '../../../../../routes/api/v1/auth/sign-out.dart' as route;
import '../../../../helpers/create_mock_request_context.dart';
import '../../../../helpers/mock_classes.dart';

void main() {
  group('POST /api/v1/auth/sign-out', () {
    late MockAuthService mockAuthService;
    late MockRequest mockRequest;

    // Define a sample authenticated user
    const testUser = User(
      id: 'user-789',
      email: 'signout@example.com',
      isAnonymous: false,
    );

    setUp(() {
      mockAuthService = MockAuthService();
      mockRequest = MockRequest();

      // Default stub for POST method
      when(() => mockRequest.method).thenReturn(HttpMethod.post);
      // Default stub for headers (authentication handled by middleware context)
      when(() => mockRequest.headers).thenReturn({});
      // Sign-out doesn't typically have a body
      when(() => mockRequest.body()).thenAnswer((_) async => '');
      when(() => mockRequest.json())
          .thenAnswer((_) async => <String, dynamic>{});
    });

    test('returns 204 No Content on successful sign-out', () async {
      // Arrange
      when(() => mockAuthService.performSignOut(userId: testUser.id))
          .thenAnswer((_) async {}); // Simulate successful void call

      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {
          AuthService: mockAuthService,
          // Provide the authenticated user via context
          User: testUser,
        },
      );

      // Act
      final response = await route.onRequest(context);

      // Assert
      expect(response.statusCode, equals(HttpStatus.noContent));
      // Verify the service method was called correctly
      verify(() => mockAuthService.performSignOut(userId: testUser.id))
          .called(1);
    });

    test('returns 405 Method Not Allowed for non-POST requests', () async {
      // Arrange
      when(() => mockRequest.method)
          .thenReturn(HttpMethod.delete); // Test DELETE
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {
          AuthService: mockAuthService,
          User: testUser, // User presence doesn't matter for method check
        },
      );

      // Act
      final response = await route.onRequest(context);

      // Assert
      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
      verifyNever(
        () => mockAuthService.performSignOut(userId: any(named: 'userId')),
      );
    });

    test('throws UnauthorizedException if user is null in context', () async {
      // Arrange
      // This scenario assumes the requireAuthentication middleware somehow failed
      // or wasn't applied.
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {
          AuthService: mockAuthService,
          // Explicitly provide null User
          User: null,
        },
      );

      // Act & Assert
      // Expect the handler to throw the exception
      expect(
        () => route.onRequest(context),
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.message,
            'message',
            'Authentication required to sign out.',
          ),
        ),
      );
      verifyNever(
        () => mockAuthService.performSignOut(userId: any(named: 'userId')),
      );
    });

    test('rethrows HtHttpException from AuthService', () async {
      // Arrange
      // Example: Maybe performSignOut throws if token invalidation fails
      const exception = OperationFailedException('Token revocation failed');
      when(() => mockAuthService.performSignOut(userId: testUser.id))
          .thenThrow(exception);

      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {
          AuthService: mockAuthService,
          User: testUser,
        },
      );

      // Act & Assert
      expect(
        () => route.onRequest(context),
        throwsA(isA<OperationFailedException>()),
      );
      verify(() => mockAuthService.performSignOut(userId: testUser.id))
          .called(1);
    });

    test('throws OperationFailedException for unexpected errors', () async {
      // Arrange
      final exception = Exception('Unexpected');
      when(() => mockAuthService.performSignOut(userId: testUser.id))
          .thenThrow(exception);

      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {
          AuthService: mockAuthService,
          User: testUser,
        },
      );

      // Act & Assert
      expect(
        () => route.onRequest(context),
        throwsA(
          isA<OperationFailedException>().having(
            (e) => e.message,
            'message',
            'An unexpected error occurred during sign-out.',
          ),
        ),
      );
      verify(() => mockAuthService.performSignOut(userId: testUser.id))
          .called(1);
    });
  });
}
