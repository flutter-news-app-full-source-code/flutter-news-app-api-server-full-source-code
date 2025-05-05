import 'package:dart_frog/dart_frog.dart';
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
      // Read the AuthTokenService provided by earlier middleware
      final tokenService = context.read<AuthTokenService>();
      User? user; // Initialize user as null

      // Extract the Authorization header
      final authHeader = context.request.headers['Authorization'];

      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        // Extract the token string
        final token = authHeader.substring(7); // Length of 'Bearer '
        try {
          // Validate the token using the service
          user = await tokenService.validateToken(token);
          if (user != null) {
            print('Authentication successful for user: ${user.id}');
          } else {
            print('Invalid token provided.');
            // Optional: Could throw UnauthorizedException here if *all* routes
            // using this middleware strictly require a valid token.
            // However, providing null allows routes to handle optional auth.
          }
        } on HtHttpException catch (e) {
          // Log token validation errors from the service
          print('Token validation failed: $e');
          // Let the error propagate if needed, or handle specific cases.
          // For now, we treat validation errors as resulting in no user.
          user = null;
        } catch (e) {
          // Catch unexpected errors during validation
          print('Unexpected error during token validation: $e');
          user = null;
        }
      } else {
        print('No valid Authorization header found.');
      }

      // Provide the User object (or null) into the context
      // This makes `context.read<User?>()` available downstream.
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
      return handler(context);
    };
  };
}
