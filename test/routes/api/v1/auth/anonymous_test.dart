import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// Import the actual route handler
import '../../../../../routes/api/v1/auth/anonymous.dart' as route;
import '../../../../helpers/create_mock_request_context.dart';
import '../../../../helpers/mock_classes.dart';

void main() {
  group('POST /api/v1/auth/anonymous', () {
    late MockAuthService mockAuthService;
    late MockRequest mockRequest;

    // Define a sample user and token for success cases
    const testUser = User(id: 'anon-123', isAnonymous: true);
    const testToken = 'test-auth-token';
    const authResult = (user: testUser, token: testToken);

    // Expected success response payload
    const successPayload = SuccessApiResponse<AuthSuccessResponse>(
      data: AuthSuccessResponse(user: testUser, token: testToken),
    );
    final expectedSuccessBody = jsonEncode(
      successPayload.toJson((auth) => auth.toJson()),
    );

    setUp(() {
      mockAuthService = MockAuthService();
      mockRequest = MockRequest();

      // Default stub for POST method
      when(() => mockRequest.method).thenReturn(HttpMethod.post);
      // Default stub for headers (can be overridden)
      when(() => mockRequest.headers).thenReturn({});
      // Default stub for body (can be overridden)
      when(() => mockRequest.body()).thenAnswer((_) async => '');
      when(() => mockRequest.json())
          .thenAnswer((_) async => <String, dynamic>{});
    });

    test('returns 200 OK with user and token on successful anonymous sign-in',
        () async {
      // Arrange
      when(() => mockAuthService.performAnonymousSignIn())
          .thenAnswer((_) async => authResult);

      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {
          AuthService: mockAuthService,
        },
      );

      // Act
      final response = await route.onRequest(context);

      // Assert
      expect(response.statusCode, equals(HttpStatus.ok));
      expect(
        await response.body(),
        equals(expectedSuccessBody),
      );
      expect(
        response.headers[HttpHeaders.contentTypeHeader],
        equals('application/json'),
      );
      verify(() => mockAuthService.performAnonymousSignIn()).called(1);
    });

    test('returns 405 Method Not Allowed for non-POST requests', () async {
      // Arrange
      when(() => mockRequest.method).thenReturn(HttpMethod.get); // Test GET
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {
          AuthService: mockAuthService,
        },
      );

      // Act
      final response = await route.onRequest(context);

      // Assert
      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
      verifyNever(() => mockAuthService.performAnonymousSignIn());
    });

    test(
        'returns 500 Internal Server Error when AuthService throws OperationFailedException',
        () async {
      // Arrange
      const exception = OperationFailedException('Database connection failed');
      when(() => mockAuthService.performAnonymousSignIn()).thenThrow(exception);

      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {
          AuthService: mockAuthService,
        },
      );

      // Act & Assert
      // Expect the handler to rethrow, letting middleware handle it
      expect(
        () => route.onRequest(context),
        throwsA(isA<OperationFailedException>()),
      );
      verify(() => mockAuthService.performAnonymousSignIn()).called(1);
      // Note: We test the *handler's* behavior (rethrowing).
      // The final 500 response format is tested in the error handler middleware tests.
    });

    test('returns 500 Internal Server Error for unexpected errors', () async {
      // Arrange
      final exception = Exception('Something unexpected went wrong');
      when(() => mockAuthService.performAnonymousSignIn()).thenThrow(exception);

      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {
          AuthService: mockAuthService,
        },
      );

      // Act & Assert
      // The handler catches generic exceptions and throws OperationFailedException
      expect(
        () => route.onRequest(context),
        throwsA(
          isA<OperationFailedException>().having(
            (e) => e.message,
            'message',
            'An unexpected error occurred during anonymous sign-in.',
          ),
        ),
      );
      verify(() => mockAuthService.performAnonymousSignIn()).called(1);
    });
  });
}
