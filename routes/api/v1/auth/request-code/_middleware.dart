import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/rate_limiter_middleware.dart';

/// This middleware applies a rate limit specifically to the
/// `/api/v1/auth/request-code` endpoint.
Handler middleware(Handler handler) {
  return handler.use(
    rateLimiter(
      limit: EnvironmentConfig.rateLimitRequestCodeLimit,
      window: EnvironmentConfig.rateLimitRequestCodeWindow,
      keyExtractor: ipKeyExtractor,
    ),
  );
}
