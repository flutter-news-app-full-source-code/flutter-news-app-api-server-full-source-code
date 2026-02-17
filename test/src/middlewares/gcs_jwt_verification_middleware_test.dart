import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/gcs_jwt_verification_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/gcs_jwt_verifier.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_helpers.dart';

class MockGcsJwtVerifier extends Mock implements IGcsJwtVerifier {}

void main() {
  group('gcsJwtVerificationMiddleware', () {
    late Handler handler;
    late MockGcsJwtVerifier mockVerifier;

    setUpAll(registerSharedFallbackValues);
    var handlerCalled = false;

    setUp(() {
      handlerCalled = false;
      mockVerifier = MockGcsJwtVerifier();
      handler = gcsJwtVerificationMiddleware(verifier: mockVerifier)((context) {
        handlerCalled = true;
        return Response(body: 'OK');
      });
    });

    test(
      'throws UnauthorizedException if Authorization header is missing',
      () async {
        final context = createMockRequestContext(
          headers: <String, String>{},
        );
        await expectLater(
          () => handler(context),
          throwsA(isA<UnauthorizedException>()),
        );
        expect(handlerCalled, isFalse);
      },
    );

    test('throws UnauthorizedException if token is not Bearer', () async {
      final context = createMockRequestContext(
        headers: {'Authorization': 'Basic some-token'},
      );
      await expectLater(
        () => handler(context),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(handlerCalled, isFalse);
    });

    test('throws UnauthorizedException on invalid signature', () async {
      final context = createMockRequestContext(
        headers: {'Authorization': 'Bearer invalid-signature-token'},
      );
      when(
        () => mockVerifier.verify(
          'invalid-signature-token',
          any(),
        ),
      ).thenThrow(const UnauthorizedException('Invalid signature.'));
      await expectLater(
        () => handler(context),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(handlerCalled, isFalse);
    });

    test('throws UnauthorizedException on invalid issuer', () async {
      final context = createMockRequestContext(
        headers: {'Authorization': 'Bearer invalid-issuer-token'},
      );
      when(
        () => mockVerifier.verify(
          'invalid-issuer-token',
          any(),
        ),
      ).thenThrow(const UnauthorizedException('Invalid issuer.'));
      await expectLater(
        () => handler(context),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(handlerCalled, isFalse);
    });

    test('throws UnauthorizedException on invalid audience', () async {
      final context = createMockRequestContext(
        headers: {'Authorization': 'Bearer invalid-audience-token'},
      );
      when(
        () => mockVerifier.verify(
          'invalid-audience-token',
          any(),
        ),
      ).thenThrow(const UnauthorizedException('Invalid audience.'));
      await expectLater(
        () => handler(context),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(handlerCalled, isFalse);
    });

    test('throws UnauthorizedException on expired token', () async {
      final context = createMockRequestContext(
        headers: {'Authorization': 'Bearer expired-token'},
      );
      when(
        () => mockVerifier.verify(
          'expired-token',
          any(),
        ),
      ).thenThrow(const UnauthorizedException('Token has expired.'));
      await expectLater(
        () => handler(context),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(handlerCalled, isFalse);
    });

    test('proceeds to next handler on valid token', () async {
      final context = createMockRequestContext(
        headers: {'Authorization': 'Bearer valid-token'},
      );
      when(
        () => mockVerifier.verify(
          'valid-token',
          any(),
        ),
      ).thenAnswer((_) async {});
      final response = await handler(context);
      expect(handlerCalled, isTrue);
      expect(response.statusCode, 200);
    });
  });
}
