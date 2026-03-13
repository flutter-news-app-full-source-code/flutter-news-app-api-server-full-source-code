import 'package:dart_frog/dart_frog.dart';
import 'package:veritai_api/src/middlewares/authentication_middleware.dart';
import 'package:veritai_api/src/middlewares/authorization_middleware.dart';
import 'package:veritai_api/src/rbac/permissions.dart';

/// Secures all routes within the `/api/v1/intelligence` group.
///
/// This middleware chain ensures that:
/// 1. A valid authentication token is present (`requireAuthentication`).
/// 2. The authenticated user has the specific `intelligence.enrich` permission
///    to use the AI enrichment features (`authorizationMiddleware`).
Handler middleware(Handler handler) {
  return handler
      .use(
        authorizationMiddleware(
          requiredPermissions: {Permissions.intelligenceEnrich},
        ),
      )
      .use(requireAuthentication());
}
