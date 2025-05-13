import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/middlewares/authentication_middleware.dart';

Handler middleware(Handler handler) {
  // This middleware applies the `authenticationProvider` to all routes
  // under /api/v1/.
  //
  // The `authenticationProvider()` (from `lib/src/middlewares/authentication_middleware.dart`):
  // 1. Attempts to extract a Bearer token from the 'Authorization' header.
  // 2. Validates the token using the `AuthTokenService` (which must be
  //    provided by an ancestor middleware, e.g., `routes/_middleware.dart`).
  // 3. Provides the resulting `User?` (nullable User object) into the request
  //    context. This makes `context.read<User?>()` available downstream.
  //
  // IMPORTANT: `authenticationProvider()` itself does NOT block unauthenticated
  // requests. It simply makes the user's identity available if authentication
  // is successful. Stricter access control (blocking unauthenticated users)
  // is handled by `requireAuthentication()` middleware applied in more specific
  // route groups (e.g., `/api/v1/data/_middleware.dart`).
  return handler.use(authenticationProvider());
}
