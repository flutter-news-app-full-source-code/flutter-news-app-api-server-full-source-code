import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';

/// Applies the ownership check to the user settings endpoint.
///
/// This runs after the parent `users/_middleware.dart`, which handles
/// authentication and permission checks. This middleware adds the final
/// security layer, ensuring a user can only access their own settings.
Handler middleware(Handler handler) {
  return handler.use(userOwnershipMiddleware());
}
