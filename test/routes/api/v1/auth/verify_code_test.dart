import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../helpers/create_mock_request_context.dart';
import '../../../../helpers/mock_classes.dart';
// Import the actual route handler
import '../../../../../routes/api/v1/auth/verify-code.dart' as route;

void main() {
  group('POST /api/v1/auth/verify-code', () {
    late MockAuthService mockAuthService;
    late MockRequest mockRequest;
    const validEmail = 'test@example.com';
    const validCode = '123456';
    final validRequestBody = jsonEncode({
      'email': validEmail,
      'code': validCode,
    });

    // Define a sample user and token for success cases
    final testUser = User(
      id: 'user-456',
      email: validEmail,
      isAnonymous: false,
    );
    const testToken = 'verified-auth-token';
    final authResult = (user: testUser, token: testToken);

    // Expected success response payload
    final successPayload = SuccessApiResponse<AuthSuccessResponse>(
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
      // Default stub for headers
      when(() => mockRequest.headers).thenReturn(
        {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      );
      // Default stub for valid body
      when(() => mockRequest.body()).thenAnswer((_) async => validRequestBody);
      when(() => mockRequest.json()).thenAnswer(
        (_) async => jsonDecode(validRequestBody) as Map<String, dynamic>,
      );
    });

    test('returns 200 OK with user and token on successful verification',
        () async {
      // Arrange
      when(() => mockAuthService.completeEmailSignIn(validEmail, validCode))
          .thenAnswer((_) async => authResult);

      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {AuthService: mockAuthService},
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
      verify(() => mockAuthService.completeEmailSignIn(validEmail, validCode))
          .called(1);
    });

    test('returns 405 Method Not Allowed for non-POST requests', () async {
      // Arrange
      when(() => mockRequest.method).thenReturn(HttpMethod.put); // Test PUT
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {AuthService: mockAuthService},
      );

      // Act
      final response = await route.onRequest(context);

      // Assert
      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
      verifyNever(() => mockAuthService.completeEmailSignIn(any(), any()));
    });

    test('throws InvalidInputException for invalid JSON body', () async {
      // Arrange
      when(() => mockRequest.json()).thenThrow(FormatException('Invalid JSON'));
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {AuthService: mockAuthService},
      );

      // Act & Assert
      expect(
        () => route.onRequest(context),
        throwsA(isA<InvalidInputException>().having(
          (e) => e.message,
          'message',
          'Invalid JSON format in request body.',
        )),
      );
      verifyNever(() => mockAuthService.completeEmailSignIn(any(), any()));
    });

     test('throws InvalidInputException for non-object JSON body', () async {
      // Arrange
      when(() => mockRequest.json()).thenAnswer((_) async => []); // Array body
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {AuthService: mockAuthService},
      );

      // Act & Assert
      expect(
        () => route.onRequest(context),
        throwsA(isA<InvalidInputException>().having(
          (e) => e.message,
          'message',
          'Request body must be a JSON object.',
        )),
      );
       verifyNever(() => mockAuthService.completeEmailSignIn(any(), any()));
    });

    test('throws InvalidInputException for missing email field', () async {
      // Arrange
      when(() => mockRequest.json()).thenAnswer((_) async => {'code': validCode});
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {AuthService: mockAuthService},
      );

      // Act & Assert
      expect(
        () => route.onRequest(context),
        throwsA(isA<InvalidInputException>().having(
          (e) => e.message,
          'message',
          'Missing or empty "email" field in request body.',
        )),
      );
       verifyNever(() => mockAuthService.completeEmailSignIn(any(), any()));
    });

     test('throws InvalidInputException for invalid email format', () async {
      // Arrange
      const invalidEmail = 'not-an-email';
       when(() => mockRequest.json()).thenAnswer((_) async => {'email': invalidEmail, 'code': validCode});
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {AuthService: mockAuthService},
      );

      // Act & Assert
      expect(
        () => route.onRequest(context),
        throwsA(isA<InvalidInputException>().having(
          (e) => e.message,
          'message',
          'Invalid email format provided.',
        )),
      );
       verifyNever(() => mockAuthService.completeEmailSignIn(any(), any()));
    });

    test('throws InvalidInputException for missing code field', () async {
      // Arrange
      when(() => mockRequest.json()).thenAnswer((_) async => {'email': validEmail});
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {AuthService: mockAuthService},
      );

      // Act & Assert
      expect(
        () => route.onRequest(context),
        throwsA(isA<InvalidInputException>().having(
          (e) => e.message,
          'message',
          'Missing or empty "code" field in request body.',
        )),
      );
       verifyNever(() => mockAuthService.completeEmailSignIn(any(), any()));
    });

     test('throws InvalidInputException for invalid code format (not 6 digits)', () async {
      // Arrange
      const invalidCode = '123';
       when(() => mockRequest.json()).thenAnswer((_) async => {'email': validEmail, 'code': invalidCode});
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {AuthService: mockAuthService},
      );

      // Act & Assert
      expect(
        () => route.onRequest(context),
        throwsA(isA<InvalidInputException>().having(
          (e) => e.message,
          'message',
          'Invalid code format. Code must be 6 digits.',
        )),
      );
       verifyNever(() => mockAuthService.completeEmailSignIn(any(), any()));
    });


    test('rethrows InvalidInputException from AuthService (e.g., wrong code)',
        () async {
      // Arrange
      const exception = InvalidInputException('Invalid or expired code.');
      when(() => mockAuthService.completeEmailSignIn(validEmail, validCode))
          .thenThrow(exception);
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {AuthService: mockAuthService},
      );

      // Act & Assert
      expect(
        () => route.onRequest(context),
        throwsA(isA<InvalidInputException>()),
      );
      verify(() => mockAuthService.completeEmailSignIn(validEmail, validCode))
          .called(1);
    });

     test('rethrows other HtHttpException from AuthService', () async {
      // Arrange
      const exception = OperationFailedException('User creation failed');
      when(() => mockAuthService.completeEmailSignIn(validEmail, validCode))
          .thenThrow(exception);
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {AuthService: mockAuthService},
      );

      // Act & Assert
      expect(
        () => route.onRequest(context),
        throwsA(isA<OperationFailedException>()),
      );
      verify(() => mockAuthService.completeEmailSignIn(validEmail, validCode))
          .called(1);
    });

    test('throws OperationFailedException for unexpected errors', () async {
      // Arrange
      final exception = Exception('Unexpected');
      when(() => mockAuthService.completeEmailSignIn(validEmail, validCode))
          .thenThrow(exception);
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {AuthService: mockAuthService},
      );

      // Act & Assert
      expect(
        () => route.onRequest(context),
        throwsA(isA<OperationFailedException>().having(
              (e) => e.message,
              'message',
              'An unexpected error occurred while verifying the sign-in code.',
            )),
      );
      verify(() => mockAuthService.completeEmailSignIn(validEmail, validCode))
          .called(1);
    });
  });
}
