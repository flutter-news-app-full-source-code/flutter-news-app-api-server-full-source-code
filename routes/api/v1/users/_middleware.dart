import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

/// Middleware for the `/api/v1/users` route group.
///
/// This middleware performs the following actions:
/// 1. `requireAuthentication()`: Ensures a user is authenticated for all
///    /users/* routes.
/// 2. `permissionSetter`: A middleware that provides the correct permission string
///    into the context *only* for the `/users` and `/users/{id}` endpoints.
///    It ignores sub-routes like `/users/{id}/settings`, leaving them to be
///    handled by their own more specific middleware.
/// 3. `authorizationMiddleware()`: Checks if the authenticated user has the
///    permission provided by the `permissionSetter`.
Handler middleware(Handler handler) {
  // This middleware provides the required permission string into the context.
  // It is scoped to only handle `/users` and `/users/{id}`.
  // ignore: prefer_function_declarations_over_variables
  final permissionSetter = (Handler handler) {
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
      final isItemRequest = pathSegments.length == 4;

      switch (request.method) {
        case HttpMethod.get:
          // Admins can list all users; users can read their own profile.
          permission =
              isItemRequest ? Permissions.userReadOwned : Permissions.userRead;
        case HttpMethod.put:
          // Users can update their own profile.
          permission = Permissions.userUpdateOwned;
        case HttpMethod.delete:
          // Users can delete their own profile.
          permission = Permissions.userDeleteOwned;
        default:
          // Disallow any other methods (e.g., POST) on this route group.
          // User creation is handled by the /auth routes.
          return Response(statusCode: 405);
      }
      // Provide the required permission to the authorization middleware.
      return handler(
        context.provide<String>(() => permission),
      );
    };
  };

  return handler
      // The authorization middleware runs after the permission has been set.
      .use(authorizationMiddleware())
      // The permission setter runs after authentication is confirmed.
      .use(permissionSetter)
      // Authentication is the first check for all /users/* routes.
      .use(requireAuthentication());
}
