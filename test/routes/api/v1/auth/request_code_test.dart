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
import '../../../../../routes/api/v1/auth/request-code.dart' as route;

void main() {
  group('POST /api/v1/auth/request-code', () {
    late MockAuthService mockAuthService;
    late MockRequest mockRequest;
    const validEmail = 'test@example.com';
    final validRequestBody = jsonEncode({'email': validEmail});

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

    test('returns 202 Accepted on successful code request', () async {
      // Arrange
      when(() => mockAuthService.initiateEmailSignIn(validEmail))
          .thenAnswer((_) async {}); // Simulate successful void call

      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {AuthService: mockAuthService},
      );

      // Act
      final response = await route.onRequest(context);

      // Assert
      expect(response.statusCode, equals(HttpStatus.accepted));
      verify(() => mockAuthService.initiateEmailSignIn(validEmail)).called(1);
    });

    test('returns 405 Method Not Allowed for non-POST requests', () async {
      // Arrange
      when(() => mockRequest.method).thenReturn(HttpMethod.get);
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {AuthService: mockAuthService},
      );

      // Act
      final response = await route.onRequest(context);

      // Assert
      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
      verifyNever(() => mockAuthService.initiateEmailSignIn(any()));
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
      verifyNever(() => mockAuthService.initiateEmailSignIn(any()));
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
       verifyNever(() => mockAuthService.initiateEmailSignIn(any()));
    });


    test('throws InvalidInputException for missing email field', () async {
      // Arrange
      when(() => mockRequest.json()).thenAnswer((_) async => <String, dynamic>{});
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
       verifyNever(() => mockAuthService.initiateEmailSignIn(any()));
    });

    test('throws InvalidInputException for empty email field', () async {
      // Arrange
       when(() => mockRequest.json()).thenAnswer((_) async => {'email': ''});
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
       verifyNever(() => mockAuthService.initiateEmailSignIn(any()));
    });


    test('throws InvalidInputException for invalid email format', () async {
      // Arrange
      const invalidEmail = 'not-an-email';
       when(() => mockRequest.json()).thenAnswer((_) async => {'email': invalidEmail});
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
       verifyNever(() => mockAuthService.initiateEmailSignIn(any()));
    });


    test('rethrows HtHttpException from AuthService', () async {
      // Arrange
      const exception = OperationFailedException('Email service down');
      when(() => mockAuthService.initiateEmailSignIn(validEmail))
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
      verify(() => mockAuthService.initiateEmailSignIn(validEmail)).called(1);
    });

    test('throws OperationFailedException for unexpected errors', () async {
      // Arrange
      final exception = Exception('Unexpected');
      when(() => mockAuthService.initiateEmailSignIn(validEmail))
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
              'An unexpected error occurred while requesting the sign-in code.',
            )),
      );
      verify(() => mockAuthService.initiateEmailSignIn(validEmail)).called(1);
    });
  });
}
