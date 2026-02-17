import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';

import 'package:test/test.dart';

import '../../../../../routes/api/v1/media/_middleware.dart';
import '../../../../src/helpers/test_helpers.dart';

void main() {
  group('Media Middleware', () {
    setUpAll(registerSharedFallbackValues);

    test('when user is not authenticated, the request is rejected '
        'before reaching the handler', () async {
      // This test verifies the *effect* of the `requireAuthentication` middleware
      // that is applied by the file under test.

      final handler = middleware(
        // This downstream handler should never be called.
        (context) {
          fail('Downstream handler should not be called.');
        },
      );

      // Create a request context that does NOT provide an authenticated user.
      // The mock helper is configured to throw a StateError when `read<User>()`
      // is called without a user being provided.
      final context = createMockRequestContext();

      // The `requireAuthentication` middleware should catch the error from
      // `context.read<User>()` and return a 401 Unauthorized response.
      // The default error-handling middleware in Dart Frog converts this to a
      // proper response. We test that the exception is thrown, as that is the
      // direct behavior of the authentication middleware.
      expect(() => handler(context), throwsA(isA<UnauthorizedException>()));
    });

    test('when user is authenticated, proceeds to the next handler', () async {
      final user = createTestUser();
      var handlerCalled = false;

      final handler = middleware((context) {
        handlerCalled = true;
        return Response(body: 'OK');
      });

      final context = createMockRequestContext(authenticatedUser: user);

      final response = await handler(context);

      expect(handlerCalled, isTrue);
      expect(response.statusCode, 200);
      expect(await response.body(), 'OK');
    });
  });
}
