import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';

/// Middleware specific to the item-level `/api/v1/data/[id]` route path.
///
/// This middleware applies the [ownershipCheckMiddleware] to perform an
/// ownership check on the requested item *after* the parent middleware
/// (`/api/v1/data/_middleware.dart`) has already performed authentication and
/// authorization checks.
///
/// This ensures that only authorized users can proceed, and then this
/// middleware adds the final layer of security by verifying item ownership
/// for non-admin users when required by the model's configuration.
Handler middleware(Handler handler) {
  // The `ownershipCheckMiddleware` will run after the middleware from
  // `/api/v1/data/_middleware.dart` (authn, authz, model validation).
  return handler.use(ownershipCheckMiddleware());
}
