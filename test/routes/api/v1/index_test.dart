import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// Import the route handler function directly.
// Adjust the import path based on your project structure if necessary.
import '../../../../routes/api/v1/index.dart' as route;

// --- Mocks ---
class _MockRequestContext extends Mock implements RequestContext {}
// --- End Mocks ---

void main() {
  late RequestContext context;

  setUp(() {
    context = _MockRequestContext();
  });

  test('responds with 200 OK and welcome message', () async {
    // No specific context setup needed for this simple route.

    // Call the onRequest function from the route file.
    final response = route.onRequest(context);

    // Assert the status code.
    expect(response.statusCode, equals(HttpStatus.ok));

    // Assert the body content.
    expect(
      await response.json(),
      equals({'message': 'Welcome to the Headlines Toolkit API V1!'}),
    );

    // Verify no unexpected interactions with the context occurred (optional).
    // verifyNever(() => context.read<dynamic>()); // Example
  });
}
