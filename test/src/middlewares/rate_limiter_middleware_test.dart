import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/middlewares/rate_limiter_middleware.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/rate_limit_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('rateLimiterMiddleware', () {
    late RateLimitService mockRateLimitService;
    late Handler handler;

    setUpAll(registerSharedFallbackValues);

    setUp(() {
      mockRateLimitService = MockRateLimitService();
      handler = (context) => Response(body: 'ok');
    });

    test(
      'calls checkRequest and proceeds when limit is not exceeded',
      () async {
        const limit = 10;
        const window = Duration(minutes: 1);
        const key = 'test-key';

        when(
          () => mockRateLimitService.checkRequest(
            key: key,
            limit: limit,
            window: window,
          ),
        ).thenAnswer((_) async {});

        final context = createMockRequestContext(
          rateLimitService: mockRateLimitService,
        );

        final middleware = rateLimiter(
          limit: limit,
          window: window,
          keyExtractor: (context) async => key,
        )(handler);

        final response = await middleware(context);

        expect(response.statusCode, equals(200));
        verify(
          () => mockRateLimitService.checkRequest(
            key: key,
            limit: limit,
            window: window,
          ),
        ).called(1);
      },
    );

    test('throws ForbiddenException when limit is exceeded', () async {
      const limit = 10;
      const window = Duration(minutes: 1);
      const key = 'test-key';

      when(
        () => mockRateLimitService.checkRequest(
          key: key,
          limit: limit,
          window: window,
        ),
      ).thenThrow(const ForbiddenException('Rate limit exceeded'));

      final context = createMockRequestContext(
        rateLimitService: mockRateLimitService,
      );

      final middleware = rateLimiter(
        limit: limit,
        window: window,
        keyExtractor: (context) async => key,
      )(handler);

      expect(() => middleware(context), throwsA(isA<ForbiddenException>()));
    });

    test('bypasses limiter when key extractor returns null', () async {
      final context = createMockRequestContext(
        rateLimitService: mockRateLimitService,
      );

      final middleware = rateLimiter(
        limit: 10,
        window: const Duration(minutes: 1),
        keyExtractor: (context) async => null,
      )(handler);

      final response = await middleware(context);

      expect(response.statusCode, equals(200));
      verifyNever(
        () => mockRateLimitService.checkRequest(
          key: any(named: 'key'),
          limit: any(named: 'limit'),
          window: any(named: 'window'),
        ),
      );
    });
  });
}
