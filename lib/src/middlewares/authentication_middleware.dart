import 'package:dart_frog/dart_frog.dart';
// Import the interface type
import 'package:ht_api/src/services/auth_token_service.dart';
import 'package:ht_shared/ht_shared.dart';

/// Middleware to handle authentication by verifying Bearer tokens.
///
/// It extracts the token from the 'Authorization' header, validates it using
/// the [AuthTokenService], and provides the resulting [User] object (or null)
/// into the request context via `context.read<User?>()`.
///
/// If a route requires authentication (determined by where this middleware is
/// applied) and the token is missing or invalid, it should ideally throw an
/// [UnauthorizedException] to be caught by the errorHandler.
///
/// **Usage:** Apply this middleware to routes or groups of routes that require
/// access to the authenticated user's identity or need protection.
Middleware authenticationProvider() {
  return (handler) {
    return (context) async {
      print('[AuthMiddleware] Entered.'); // Log 1: Entry
      // Read the interface type
      AuthTokenService tokenService;
      try {
        print(
          '[AuthMiddleware] Attempting to read AuthTokenService...',
        ); // Log 2: Before read
        tokenService = context.read<AuthTokenService>();
        print(
          '[AuthMiddleware] Successfully read AuthTokenService.',
        ); // Log 3: After read
      } catch (e, s) {
        print(
          '[AuthMiddleware] FAILED to read AuthTokenService: $e\n$s',
        ); // Log Error
        // Re-throw the error to be caught by the main error handler
        rethrow;
      }
      User? user; // Initialize user as null

      // Extract the Authorization header
      print(
        '[AuthMiddleware] Attempting to read Authorization header...',
      ); // Log 4: Before header read
      final authHeader = context.request.headers['Authorization'];
      print(
        '[AuthMiddleware] Authorization header value: $authHeader',
      ); // Log 5: Header value

      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        // Extract the token string
        final token = authHeader.substring(7); // Length of 'Bearer '
        print(
          '[AuthMiddleware] Extracted Bearer token.',
        ); // Log 6: Token extracted
        try {
          print(
            '[AuthMiddleware] Attempting to validate token...',
          ); // Log 7: Before validate
          // Validate the token using the service
          user = await tokenService.validateToken(token);
          print(
            '[AuthMiddleware] Token validation returned: ${user?.id ?? 'null'}',
          ); // Log 8: After validate
          if (user != null) {
            print(
              '[AuthMiddleware] Authentication successful for user: ${user.id}',
            );
          } else {
            print(
              '[AuthMiddleware] Invalid token provided (validateToken returned null).',
            );
            // Optional: Could throw UnauthorizedException here if *all* routes
            // using this middleware strictly require a valid token.
            // However, providing null allows routes to handle optional auth.
          }
        } on HtHttpException catch (e) {
          // Log token validation errors from the service
          print('Token validation failed: $e');
          // Let the error propagate if needed, or handle specific cases.
          // For now, we treat validation errors as resulting in no user.
          user = null; // Keep user null if HtHttpException occurred
        } catch (e, s) {
          // Catch unexpected errors during validation
          print(
            '[AuthMiddleware] Unexpected error during token validation: $e\n$s',
          );
          user = null; // Keep user null if unexpected error occurred
        }
      } else {
        print('[AuthMiddleware] No valid Bearer token found in header.');
      }

      // Provide the User object (or null) into the context
      // This makes `context.read<User?>()` available downstream.
      print(
        '[AuthMiddleware] Providing User (${user?.id ?? 'null'}) to context.',
      ); // Log 9: Before provide
      return handler(context.provide<User?>(() => user));
    };
  };
}

/// Middleware factory that ensures a valid authenticated user exists.
///
/// Use this for routes that *strictly require* a logged-in user.
/// It reads the `User?` provided by `authenticationProvider` and throws
/// [UnauthorizedException] if the user is null.
Middleware requireAuthentication() {
  return (handler) {
    return (context) {
      final user = context.read<User?>();
      if (user == null) {
        print(
          'Authentication required but no valid user found. Denying access.',
        );
        // Throwing allows the central errorHandler to create the 401 response.
        throw const UnauthorizedException('Authentication required.');
      }
      // If user exists, proceed to the handler
      print('Authentication check passed for user: ${user.id}');
      return handler(context.provide<User>(() => user)); // Provide non-nullable User
    };
  };
}
