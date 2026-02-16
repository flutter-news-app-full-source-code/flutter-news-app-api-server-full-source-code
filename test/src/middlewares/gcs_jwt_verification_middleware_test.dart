import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/gcs_jwt_verification_middleware.dart';
import 'package:jose/jose.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_helpers.dart';

class MockJsonWebSignature extends Mock implements JsonWebSignature {}

class MockJsonWebKeyStore extends Mock implements JsonWebKeyStore {}

class MockJsonWebToken extends Mock implements JsonWebToken {}

void main() {
  group('gcsJwtVerificationMiddleware', () {
    late Handler handler;
    var handlerCalled = false;

    setUp(() {
      handlerCalled = false;
      handler = gcsJwtVerificationMiddleware()((context) {
        handlerCalled = true;
        return Response(body: 'OK');
      });
      mockGcsJwtVerification();
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
      final response = await handler(context);
      expect(handlerCalled, isTrue);
      expect(response.statusCode, 200);
    });
  });
}
