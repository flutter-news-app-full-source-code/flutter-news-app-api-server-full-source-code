// Middleware for /api/v1/users/[userId]/settings
// Ensures that all routes within this group require authentication.

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/middlewares/authentication_middleware.dart';

Handler middleware(Handler handler) {
  // Apply `requireAuthentication()` to protect all settings routes within the
  // /api/v1/users/[userId]/settings/ path.
  //
  // This middleware relies on `authenticationProvider()` (applied in the parent
  // `/api/v1/_middleware.dart`) to have already:
  // 1. Attempted to authenticate the user from a Bearer token.
  // 2. Provided `User?` (nullable User) into the request context.
  //
  // `requireAuthentication()` then checks this `User?` from the context:
  // - If `User` is null (meaning no valid authentication was established by
  //   `authenticationProvider`), it throws an `UnauthorizedException`.
  //   This typically results in a 401 HTTP response via the global `errorHandler`.
  // - If `User` is present (not null), the request is allowed to proceed to the
  //   actual route handler (e.g., display.dart, language.dart).
  //
  // This ensures that all settings endpoints are strictly accessible only by
  // authenticated users, and `context.read<User>()` (non-nullable) can be
  // safely used within these route handlers.
  return handler.use(requireAuthentication());
}
