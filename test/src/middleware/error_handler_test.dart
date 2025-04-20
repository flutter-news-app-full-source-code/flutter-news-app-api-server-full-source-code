import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/middleware/error_handler.dart'; // Import the handler
import 'package:ht_countries_client/ht_countries_client.dart'; // Import exceptions
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// --- Mocks ---
class _MockRequestContext extends Mock implements RequestContext {}

// Define a class that can be called like a Handler function
// ignore: one_member_abstracts
abstract class _CallableHandler {
  Future<Response> call(RequestContext context);
}

// Mock the callable class instead of the typedef
class _MockHandler extends Mock implements _CallableHandler {}
// --- End Mocks ---

void main() {
  late RequestContext context;
  late Middleware middleware;
  late _MockHandler mockHandler; // Use the mock class instance

  setUp(() {
    context = _MockRequestContext();
    middleware = errorHandler(); // Create instance of the middleware
    mockHandler = _MockHandler(); // Instantiate the mock class

    // Register fallback value for RequestContext if needed by mocktail
    registerFallbackValue(context);
  });

  // Helper function to apply middleware and execute the handler
  Future<Response> executeMiddleware(RequestContext ctx, Handler h) async {
    final handlerWithMiddleware = middleware(h);
    return handlerWithMiddleware(ctx);
  }

  test('should return response from inner handler when no error occurs',
      () async {
    final expectedResponse = Response(body: 'Success');
    // Configure the mock handler's 'call' method
    when(() => mockHandler.call(any()))
        .thenAnswer((_) async => expectedResponse);

    // Execute the middleware chain, passing the mock handler's call method
    final response = await executeMiddleware(context, mockHandler.call);

    // Assert that the response is the one returned by the inner handler
    expect(response, equals(expectedResponse));
    // Verify the mock handler's call method was invoked
    verify(() => mockHandler.call(context)).called(1);
  });

  group('Error Handling', () {
    test('should return 400 on FormatException', () async {
      const exception = FormatException('Invalid JSON');
      // Configure the mock handler's 'call' method to throw
      when(() => mockHandler.call(any())).thenThrow(exception);

      // Execute the middleware chain
      final response = await executeMiddleware(context, mockHandler.call);

      // Assert the response status code and body
      expect(response.statusCode, equals(HttpStatus.badRequest));
      expect(
        await response.json(),
        equals({'error': 'Invalid request format: ${exception.message}'}),
      );
      verify(() => mockHandler.call(context)).called(1);
    });

    test('should return 404 on CountryNotFound', () async {
      const exception = CountryNotFound('Test country not found');
      when(() => mockHandler.call(any())).thenThrow(exception);

      final response = await executeMiddleware(context, mockHandler.call);

      expect(response.statusCode, equals(HttpStatus.notFound));
      expect(
        await response.json(),
        equals({'error': 'Country not found: ${exception.error}'}),
      );
      verify(() => mockHandler.call(context)).called(1);
    });

    test('should return 500 on CountryFetchFailure', () async {
      const exception = CountryFetchFailure('Network error');
      when(() => mockHandler.call(any())).thenThrow(exception);

      final response = await executeMiddleware(context, mockHandler.call);

      expect(response.statusCode, equals(HttpStatus.internalServerError));
      expect(
        await response.json(),
        equals({'error': 'Failed to fetch country data: ${exception.error}'}),
      );
      verify(() => mockHandler.call(context)).called(1);
    });

    test('should return 500 on CountryCreateFailure', () async {
      const exception = CountryCreateFailure('Database constraint violated');
      when(() => mockHandler.call(any())).thenThrow(exception);

      final response = await executeMiddleware(context, mockHandler.call);

      expect(response.statusCode, equals(HttpStatus.internalServerError));
      expect(
        await response.json(),
        equals({'error': 'Failed to create country: ${exception.error}'}),
      );
      verify(() => mockHandler.call(context)).called(1);
    });

    test('should return 500 on CountryUpdateFailure', () async {
      const exception = CountryUpdateFailure('Update conflict');
      when(() => mockHandler.call(any())).thenThrow(exception);

      final response = await executeMiddleware(context, mockHandler.call);

      expect(response.statusCode, equals(HttpStatus.internalServerError));
      expect(
        await response.json(),
        equals({'error': 'Failed to update country: ${exception.error}'}),
      );
      verify(() => mockHandler.call(context)).called(1);
    });

    test('should return 500 on CountryDeleteFailure', () async {
      const exception = CountryDeleteFailure('Permission denied');
      when(() => mockHandler.call(any())).thenThrow(exception);

      final response = await executeMiddleware(context, mockHandler.call);

      expect(response.statusCode, equals(HttpStatus.internalServerError));
      expect(
        await response.json(),
        equals({'error': 'Failed to delete country: ${exception.error}'}),
      );
      verify(() => mockHandler.call(context)).called(1);
    });

    test('should return 500 on generic Exception', () async {
      final exception = Exception('Something unexpected happened');
      when(() => mockHandler.call(any())).thenThrow(exception);

      final response = await executeMiddleware(context, mockHandler.call);

      expect(response.statusCode, equals(HttpStatus.internalServerError));
      expect(
        await response.json(),
        equals({'error': 'An unexpected server error occurred.'}),
      );
      verify(() => mockHandler.call(context)).called(1);
    });
  });
}
