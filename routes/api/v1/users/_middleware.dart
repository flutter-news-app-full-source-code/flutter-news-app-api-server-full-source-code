import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/configured_rate_limiter.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

/// Middleware for the `/api/v1/users` route group.
///
/// This middleware performs the following actions:
/// 1. `requireAuthentication()`: Ensures a user is authenticated for all
///    /users/* routes.
/// 2. `rateAndPermissionSetter`: A middleware that applies rate limiting and
///    provides the correct permission string into the context *only* for the
///    `/users` and `/users/{id}` endpoints. It ignores sub-routes like
///    `/users/{id}/settings`, leaving them to be handled by their own more
///    specific middleware.
/// 3. `authorizationMiddleware()`: Checks if the authenticated user has the
///    permission provided by the `rateAndPermissionSetter`.
Handler middleware(Handler handler) {
  // This middleware applies rate limiting and provides the required permission.
  // It is scoped to only handle `/users` and `/users/{id}`.
  // ignore: prefer_function_declarations_over_variables
  final rateAndPermissionSetter = (Handler handler) {
    return (RequestContext context) {
      final request = context.request;
      final pathSegments = request.uri.pathSegments;

      // This logic only applies to /users (length 3) and /users/{id} (length 4).
      // It intentionally ignores longer paths like /users/{id}/settings (length 5),
      // allowing sub-route middleware to handle them.
      if (pathSegments.length > 4) {
        return handler(context);
      }

      final String permission;
      final Middleware rateLimiter;
      final isItemRequest = pathSegments.length == 4;

      switch (request.method) {
        case HttpMethod.get:
          // Admins can list all users; users can read their own profile.
          permission =
              isItemRequest ? Permissions.userReadOwned : Permissions.userRead;
          rateLimiter = createReadRateLimiter();
        case HttpMethod.put:
          // Users can update their own profile.
          permission = Permissions.userUpdateOwned;
          rateLimiter = createWriteRateLimiter();
        case HttpMethod.delete:
          // Users can delete their own profile.
          permission = Permissions.userDeleteOwned;
          rateLimiter = createWriteRateLimiter();
        default:
          // Disallow any other methods (e.g., POST) on this route group.
          // User creation is handled by the /auth routes.
          return Response(statusCode: 405);
      }

      // Apply the selected rate limiter and then provide the permission.
      return rateLimiter(
        (context) => handler(
          context.provide<String>(() => permission),
        ),
      )(context);
    };
  };

  return handler
      // The authorization middleware runs after the permission has been set.
      .use(authorizationMiddleware())
      // The rate limiter and permission setter runs after authentication.
      .use(rateAndPermissionSetter)
      // Authentication is the first check for all /users/* routes.
      .use(requireAuthentication());
}
