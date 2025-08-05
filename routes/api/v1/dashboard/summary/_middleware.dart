import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

/// Middleware for the `/api/v1/dashboard/summary` route.
///
/// This middleware chain ensures that only authenticated administrators
/// can access this route.
Handler middleware(Handler handler) {
  return handler
      .use(
        (handler) => (context) {
          // This endpoint only supports GET.
          if (context.request.method != HttpMethod.get) {
            return Response(statusCode: 405);
          }
          // Provide the required permission to the authorization middleware.
          return handler(
            context.provide<String>(() => Permissions.dashboardLogin),
          );
        },
      )
      .use(authorizationMiddleware())
      .use(requireAuthentication());
}
