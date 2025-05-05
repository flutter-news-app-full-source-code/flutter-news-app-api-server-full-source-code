import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// Import RequestId definition from middleware file
import '../../../../../routes/_middleware.dart' show RequestId;
// Import the actual route handler
import '../../../../../routes/api/v1/auth/me.dart' as route;
import '../../../../helpers/create_mock_request_context.dart';
import '../../../../helpers/mock_classes.dart';

void main() {
  group('GET /api/v1/auth/me', () {
    late MockRequest mockRequest;

    // Define a sample authenticated user
    const testUser = User(
      id: 'user-123',
      email: 'test@example.com',
      isAnonymous: false,
    );
    const testRequestIdValue = 'req-abc-123';
    const testRequestId = RequestId(testRequestIdValue);

    setUp(() {
      mockRequest = MockRequest();
      // Default stub for GET method
      when(() => mockRequest.method).thenReturn(HttpMethod.get);
      // Default stub for headers (authentication handled by middleware context)
      when(() => mockRequest.headers).thenReturn({});
    });

    test('returns 200 OK with user data for authenticated user', () async {
      // Arrange
      // Expected success response payload (metadata timestamp will vary)
      const expectedPayload = SuccessApiResponse<User>(data: testUser);
      final expectedBody = jsonEncode(
        // We ignore metadata for direct comparison as timestamp varies
        expectedPayload.toJson((user) => user.toJson())..remove('metadata'),
      );

      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {
          // Provide the authenticated user via context
          User: testUser,
          // Provide RequestId for metadata test
          RequestId: testRequestId,
        },
      );

      // Act
      final response = await route.onRequest(context);
      final responseBody = await response.body();
      final decodedBody = jsonDecode(responseBody) as Map<String, dynamic>;

      // Assert
      expect(response.statusCode, equals(HttpStatus.ok));
      // Compare data part only
      expect(decodedBody['data'], equals(jsonDecode(expectedBody)['data']));
      expect(
        response.headers[HttpHeaders.contentTypeHeader],
        equals('application/json'),
      );
      // Check metadata structure and requestId presence
      expect(decodedBody['metadata'], isA<Map<String, dynamic>>());
      expect(
          decodedBody['metadata']?['request_id'], equals(testRequestIdValue),);
      expect(decodedBody['metadata']?['timestamp'], isNotNull);
    });

    test('returns 200 OK with user data when RequestId is not in context',
        () async {
      // Arrange
      // Expected success response payload (metadata timestamp will vary)
      const expectedPayload = SuccessApiResponse<User>(data: testUser);
      final expectedBody = jsonEncode(
        // We ignore metadata for direct comparison as timestamp varies
        expectedPayload.toJson((user) => user.toJson())..remove('metadata'),
      );

      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {
          // Provide the authenticated user via context
          User: testUser,
          // DO NOT provide RequestId
        },
      );

      // Act
      final response = await route.onRequest(context);
      final responseBody = await response.body();
      final decodedBody = jsonDecode(responseBody) as Map<String, dynamic>;

      // Assert
      expect(response.statusCode, equals(HttpStatus.ok));
      // Compare data part only
      expect(decodedBody['data'], equals(jsonDecode(expectedBody)['data']));
      expect(
        response.headers[HttpHeaders.contentTypeHeader],
        equals('application/json'),
      );
      // Check metadata structure and requestId absence/null
      expect(decodedBody['metadata'], isA<Map<String, dynamic>>());
      expect(decodedBody['metadata']?['request_id'], isNull); // Should be null
      expect(decodedBody['metadata']?['timestamp'], isNotNull);
    });

    test('returns 405 Method Not Allowed for non-GET requests', () async {
      // Arrange
      when(() => mockRequest.method).thenReturn(HttpMethod.post); // Test POST
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {
          User: testUser, // User presence doesn't matter for method check
        },
      );

      // Act
      final response = await route.onRequest(context);

      // Assert
      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
    });

    test('throws UnauthorizedException if user is null in context (safeguard)',
        () async {
      // Arrange
      // This scenario assumes the requireAuthentication middleware somehow failed
      // or wasn't applied, letting the request reach the handler without a user.
      final context = createMockRequestContext(
        request: mockRequest,
        dependencies: {
          // Explicitly provide null User
          User: null,
        },
      );

      // Act & Assert
      // Expect the handler to throw the exception, letting middleware handle it
      expect(
        () => route.onRequest(context),
        throwsA(isA<UnauthorizedException>()),
      );
      // Note: The final 401 response format is tested in error handler tests.
    });
  });
}
