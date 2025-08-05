import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/configured_rate_limiter.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

/// Headlines are managed by admins and publishers, but are readable by all
/// authenticated users. This middleware also applies rate limiting.
Handler middleware(Handler handler) {
  return handler
      .use(
        (handler) => (context) {
          final request = context.request;
          final String permission;
          final Middleware rateLimiter;

          switch (request.method) {
            case HttpMethod.get:
              permission = Permissions.headlineRead;
              rateLimiter = createReadRateLimiter();
            case HttpMethod.post:
              permission = Permissions.headlineCreate;
              rateLimiter = createWriteRateLimiter();
            case HttpMethod.put:
              permission = Permissions.headlineUpdate;
              rateLimiter = createWriteRateLimiter();
            case HttpMethod.delete:
              permission = Permissions.headlineDelete;
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
