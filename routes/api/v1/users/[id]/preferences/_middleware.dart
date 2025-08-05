import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

/// Middleware for the user preferences endpoint.
///
/// This chain ensures that:
/// 1. The user is authenticated (handled by the parent `users` middleware).
/// 2. The correct permission (`userContentPreferences...`) is required.
/// 3. The user has that permission.
/// 4. The user is the owner of the preferences resource.
Handler middleware(Handler handler) {
 
  return handler
      // Final check: ensure the authenticated user owns this resource.
      .use(userOwnershipMiddleware())
      // Check if the user has the required permission.
      .use(authorizationMiddleware())
      // Provide the specific permission required for this route.
      .use(_permissionSetter());
}

Middleware _permissionSetter() {
  return (handler) {
    return (context) {
      final String permission;
      switch (context.request.method) {
        case HttpMethod.get:
          permission = Permissions.userContentPreferencesReadOwned;
        case HttpMethod.put:
          permission = Permissions.userContentPreferencesUpdateOwned;
        default:
          return Response(statusCode: 405);
      }
      return handler(context.provide<String>(() => permission));
    };
  };
}

