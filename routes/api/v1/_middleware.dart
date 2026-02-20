import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:logging/logging.dart';

final _log = Logger('ApiV1Middleware');

Handler middleware(Handler handler) {
  // This middleware applies authentication to all routes under `/api/v1/`.
  // CORS is now handled by the root middleware.
  return handler.use((handler) {
    // This is a custom middleware to wrap the auth provider with logging.
    final authMiddleware = authenticationProvider();
    final authHandler = authMiddleware(handler);

    return (context) {
      _log.info('[REQ_LIFECYCLE] Entering authentication middleware...');
      return authHandler(context);
    };
  });
}
