import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/rate_limiter_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/rate_limit_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('rateLimiterMiddleware', () {
    late RateLimitService mockRateLimitService;
    late Handler handler;

    setUpAll(() {
      registerFallbackValue(const Duration(seconds: 1));
    });

    setUp(() {
      mockRateLimitService = MockRateLimitService();
      handler = (context) => Response(body: 'ok');
    });

    const limit = 100;
    const window = Duration(minutes: 1);

    Future<String?> keyExtractor(RequestContext context) async => 'test-key';

    test('calls handler when rate limit is not exceeded', () async {
      when(
        () => mockRateLimitService.checkRequest(
          key: 'test-key',
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
        keyExtractor: keyExtractor,
      )(handler);

      final response = await middleware(context);
      expect(await response.body(), 'ok');
      verify(
        () => mockRateLimitService.checkRequest(
          key: 'test-key',
          limit: limit,
          window: window,
        ),
      ).called(1);
    });

    test('propagates exception when rate limit is exceeded', () async {
      const exception = ForbiddenException('Rate limit exceeded');
      when(
        () => mockRateLimitService.checkRequest(
          key: 'test-key',
          limit: limit,
          window: window,
        ),
      ).thenThrow(exception);

      final context = createMockRequestContext(
        rateLimitService: mockRateLimitService,
      );

      final middleware = rateLimiter(
        limit: limit,
        window: window,
        keyExtractor: keyExtractor,
      )(handler);

      expect(() => middleware(context), throwsA(isA<ForbiddenException>()));
    });

    test('bypasses limiter when key extractor returns null', () async {
      final context = createMockRequestContext(
        rateLimitService: mockRateLimitService,
      );

      final middleware = rateLimiter(
        limit: limit,
        window: window,
        keyExtractor: (context) async => null,
      )(handler);

      final response = await middleware(context);
      expect(await response.body(), 'ok');
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
