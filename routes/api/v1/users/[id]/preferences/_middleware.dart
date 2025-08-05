import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

/// Middleware for the `/api/v1/users/[id]/preferences` route.
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

          switch (request.method) {
            case HttpMethod.get:
              permission = Permissions.userContentPreferencesReadOwned;
            case HttpMethod.put:
              permission = Permissions.userContentPreferencesUpdateOwned;
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
