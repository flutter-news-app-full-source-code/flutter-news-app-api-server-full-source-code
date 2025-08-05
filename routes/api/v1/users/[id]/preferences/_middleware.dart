import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/configured_rate_limiter.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

/// Middleware for the user preferences endpoint.
///
/// This chain ensures that:
/// 1. The user is authenticated (handled by the parent `users` middleware).
/// 2. Rate limiting is applied.
/// 3. The correct permission (`userContentPreferences...`) is required.
/// 4. The user has that permission.
/// 5. The user is the owner of the preferences resource.
Handler middleware(Handler handler) {
  return handler
      // Final check: ensure the authenticated user owns this resource.
      .use(userOwnershipMiddleware())
      // Check if the user has the required permission.
      .use(authorizationMiddleware())
      // Apply rate limiting and provide the specific permission for this route.
      .use(_rateAndPermissionSetter());
}

Middleware _rateAndPermissionSetter() {
  return (handler) {
    return (context) {
      final String permission;
      final Middleware rateLimiter;

      switch (context.request.method) {
        case HttpMethod.get:
          permission = Permissions.userContentPreferencesReadOwned;
          rateLimiter = createReadRateLimiter();
        case HttpMethod.put:
          permission = Permissions.userContentPreferencesUpdateOwned;
          rateLimiter = createWriteRateLimiter();
        default:
          return Response(statusCode: 405);
      }

      return rateLimiter(
        (context) => handler(
          context.provide<String>(() => permission),
        ),
      )(context);
    };
  };
}
