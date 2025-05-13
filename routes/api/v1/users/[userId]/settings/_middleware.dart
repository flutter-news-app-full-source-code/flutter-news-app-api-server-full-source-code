// Middleware for /api/v1/users/[userId]/settings
// Ensures that all routes within this group require authentication.

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/middlewares/authentication_middleware.dart';

Handler middleware(Handler handler) {
  // Apply requireAuthentication to protect all settings routes.
  // This ensures that context.read<User>() will be non-null in these handlers.
  return handler.use(requireAuthentication());
}
