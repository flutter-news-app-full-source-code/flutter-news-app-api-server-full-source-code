import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

/// Headlines are managed by admins and publishers, but are readable by all
/// authenticated users.
Handler middleware(Handler handler) {
  return handler
      .use(
        (handler) => (context) {
          final request = context.request;
          final String permission;

          switch (request.method) {
            case HttpMethod.get:
              permission = Permissions.headlineRead;
            case HttpMethod.post:
              permission = Permissions.headlineCreate;
            case HttpMethod.put:
              permission = Permissions.headlineUpdate;
            case HttpMethod.delete:
              permission = Permissions.headlineDelete;
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
