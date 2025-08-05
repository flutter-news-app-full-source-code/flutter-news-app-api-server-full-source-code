import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

/// Middleware for the singleton `/api/v1/remote-config` route.
///
/// This middleware chain enforces the following access rules:
/// - GET: Requires `remoteConfig.read` permission.
/// - PUT: Requires `remoteConfig.update` permission (admin-only).
/// - Other methods (POST, DELETE, etc.) are disallowed.
Handler middleware(Handler handler) {
  return handler
      .use(
        (handler) => (context) {
          final request = context.request;
          final String permission;

          switch (request.method) {
            case HttpMethod.get:
              permission = Permissions.remoteConfigRead;
              break;
            case HttpMethod.put:
              permission = Permissions.remoteConfigUpdate;
              break;
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
