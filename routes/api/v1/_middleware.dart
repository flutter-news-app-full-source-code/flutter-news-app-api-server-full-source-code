import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/middlewares/authentication_middleware.dart';

Handler middleware(Handler handler) {
  // This middleware applies authentication to all routes under /api/v1/.
  // It expects AuthTokenService to be provided by an ancestor middleware
  // (e.g., the global routes/_middleware.dart).
  return handler.use(authenticationProvider());
}
