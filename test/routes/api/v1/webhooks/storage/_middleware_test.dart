import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/gcs_jwt_verifier.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../../routes/api/v1/webhooks/storage/_middleware.dart';
import '../../../../../src/helpers/test_helpers.dart';

class MockGcsJwtVerifier extends Mock implements IGcsJwtVerifier {}

void main() {
  group('Webhook Storage Middleware', () {
    setUpAll(registerSharedFallbackValues);
    const validToken = 'valid-jwt-token';
    const requestHost = 'test.com';

    test('allows request when JWT verification succeeds', () async {
      final verifier = MockGcsJwtVerifier();
      var handlerCalled = false;
      final handler = middleware((context) {
        handlerCalled = true;
        return Response(body: 'OK');
      });

      when(
        () => verifier.verify(validToken, requestHost),
      ).thenAnswer((_) => Future.value());

      final context = createMockRequestContext(
        gcsJwtVerifier: verifier,
        headers: {'Authorization': 'Bearer $validToken'},
        path: '/api/v1/webhooks/storage',
      );

      final response = await handler(context);

      expect(response.statusCode, equals(200));
      expect(handlerCalled, isTrue);
      verify(() => verifier.verify(validToken, requestHost)).called(1);
    });

    test('rejects request when JWT verification fails', () async {
      final verifier = MockGcsJwtVerifier();
      var handlerCalled = false;
      final handler = middleware((context) {
        handlerCalled = true;
        return Response(body: 'OK');
      });

      when(
        () => verifier.verify(validToken, requestHost),
      ).thenThrow(const UnauthorizedException('test failure'));

      final context = createMockRequestContext(
        gcsJwtVerifier: verifier,
        headers: {'Authorization': 'Bearer $validToken'},
        path: '/api/v1/webhooks/storage',
      );

      await expectLater(
        () => handler(context),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(handlerCalled, isFalse);
      verify(() => verifier.verify(validToken, requestHost)).called(1);
    });

    test('rejects request when Authorization header is missing', () async {
      final verifier = MockGcsJwtVerifier();
      final handler = middleware((context) => Response(body: 'OK'));
      final context = createMockRequestContext(gcsJwtVerifier: verifier);

      await expectLater(
        () => handler(context),
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.message,
            'message',
            'Missing or invalid token.',
          ),
        ),
      );
    });
  });
}
