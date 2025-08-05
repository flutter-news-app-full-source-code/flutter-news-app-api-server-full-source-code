import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

/// Middleware for the `/api/v1/users` route.
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
          // A request is for a specific item if it has more than 3 path segments:
          // e.g., /api/v1/users/{id}
          final isItemRequest = request.uri.pathSegments.length > 3;

          switch (request.method) {
            case HttpMethod.get:
              permission = isItemRequest
                  ? Permissions.userReadOwned
                  : Permissions.userRead;
            case HttpMethod.put:
              permission = Permissions.userUpdateOwned;
            case HttpMethod.delete:
              permission = Permissions.userDeleteOwned;
            default:
              // Return 405 Method Not Allowed for unsupported methods.
              return Response(statusCode: 405);
          }
          // Provide the required permission to the authorization middleware.
          return handler(
            context.provide<String>(() => permission),
          );
        },
      )
      .use(authorizationMiddleware())
      .use(requireAuthentication());
}
