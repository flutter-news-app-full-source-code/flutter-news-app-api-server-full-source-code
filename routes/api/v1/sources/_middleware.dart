import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/configured_rate_limiter.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

/// Sources are managed by admins, but are readable by all authenticated users.
/// This middleware also applies rate limiting.
///
/// Middleware for the `/api/v1/sources` route.
///
/// This middleware chain performs the following actions:
/// 1. `requireAuthentication()`: Ensures the user is authenticated.
/// 2. `authorizationMiddleware()`: Checks if the authenticated user has the
///    necessary permission to perform the requested action.
/// 3. The inner middleware provides the specific permission required for the
///    current request to the `authorizationMiddleware`.
Handler middleware(Handler handler) {
  return handler
      .use(
        (handler) => (context) {
          final request = context.request;
          final String permission;
          final Middleware rateLimiter;

          switch (request.method) {
            case HttpMethod.get:
              permission = Permissions.sourceRead;
              rateLimiter = createReadRateLimiter();
            case HttpMethod.post:
              permission = Permissions.sourceCreate;
              rateLimiter = createWriteRateLimiter();
            case HttpMethod.put:
              permission = Permissions.sourceUpdate;
              rateLimiter = createWriteRateLimiter();
            case HttpMethod.delete:
              permission = Permissions.sourceDelete;
              rateLimiter = createWriteRateLimiter();
            default:
              // Return 405 Method Not Allowed for unsupported methods.
              return Response(statusCode: 405);
          }

          // Apply the selected rate limiter and then provide the permission.
          return rateLimiter(
            (context) => handler(
              context.provide<String>(() => permission),
            ),
          )(context);
        },
      )
      .use(authorizationMiddleware())
      .use(requireAuthentication());
}
