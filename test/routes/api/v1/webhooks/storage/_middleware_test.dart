import 'package:dart_frog/dart_frog.dart';
import 'package:test/test.dart';

import '../../../../../../routes/api/v1/webhooks/storage/_middleware.dart';
import '../../../../../src/helpers/test_helpers.dart';

void main() {
  group('Webhook Storage Middleware', () {
    setUpAll(registerSharedFallbackValues);

    test('applies GCS JWT verification middleware', () async {
      // This test is primarily to ensure the middleware is composed correctly.
      // The detailed logic of JWT verification is tested in its own file.
      // We mock the verification to always pass to test the handler chain.
      mockGcsJwtVerification();

      var handlerCalled = false;
      final handler = middleware((context) {
        handlerCalled = true;
        return Response(body: 'OK');
      });

      final context = createMockRequestContext(
        headers: {'Authorization': 'Bearer valid-token'},
      );
      await handler(context);
      expect(handlerCalled, isTrue);
    });
  });
}
