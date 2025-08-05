import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

Handler middleware(Handler handler) {
  return handler
      .use(
        (handler) => (context) {
          final request = context.request;
          final String permission;
          // Check if the request is for a specific item by looking at the path.
          final isItemRequest = request.uri.pathSegments.length > 3;

          switch (request.method) {
            case HttpMethod.get:
              permission = isItemRequest
                  ? Permissions.headlineRead
                  : Permissions.headlineRead;
            case HttpMethod.post:
              permission = Permissions.headlineCreate;
            case HttpMethod.put:
              permission = Permissions.headlineUpdate;
            case HttpMethod.delete:
              permission = Permissions.headlineDelete;
            default:
              // This will be caught by the error handler.
              return Response(statusCode: 405);
          }
          return handler(
            context.provide<String>(() => permission),
          );
        },
      )
      .use(authorizationMiddleware())
      .use(requireAuthentication());
}
