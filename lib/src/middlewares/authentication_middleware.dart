import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('AuthMiddleware');

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
      _log.finer('Entered.');
      // Read the interface type
      AuthTokenService tokenService;
      try {
        _log.finer('Attempting to read AuthTokenService...');
        tokenService = context.read<AuthTokenService>();
        _log.finer('Successfully read AuthTokenService.');
      } catch (e, s) {
        _log.severe('FAILED to read AuthTokenService.', e, s);
        // Re-throw the error to be caught by the main error handler
        rethrow;
      }
      User? user;

      // Extract the Authorization header
      _log.finer('Attempting to read Authorization header...');
      final authHeader = context.request.headers['Authorization'];
      _log.finer('Authorization header value: $authHeader');

      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        // Extract the token string
        final token = authHeader.substring(7);
        _log.finer('Extracted Bearer token.');
        try {
          _log.finer('Attempting to validate token...');
          // Validate the token using the service
          user = await tokenService.validateToken(token);
          _log.finer('Token validation returned: ${user?.id ?? 'null'}');
          if (user != null) {
            _log.info('Authentication successful for user: ${user.id}');
          } else {
            _log.warning(
              'Invalid token provided (validateToken returned null).',
            );
            // Optional: Could throw UnauthorizedException here if *all* routes
            // using this middleware strictly require a valid token.
            // However, providing null allows routes to handle optional auth.
          }
        } on HttpException catch (e) {
          // Log token validation errors from the service
          _log.warning('Token validation failed.', e);
          // Let the error propagate if needed, or handle specific cases.
          // For now, we treat validation errors as resulting in no user.
          user = null;
        } catch (e, s) {
          // Catch unexpected errors during validation
          _log.severe('Unexpected error during token validation.', e, s);
          user = null;
        }
      } else {
        _log.finer('No valid Bearer token found in header.');
      }

      // Provide the User object (or null) into the context
      // This makes `context.read<User?>()` available downstream.
      _log.finer('Providing User (${user?.id ?? 'null'}) to context.');
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
        _log.warning(
          'Authentication required but no valid user found. Denying access.',
        );
        // Throwing allows the central errorHandler to create the 401 response.
        throw const UnauthorizedException('Authentication required.');
      }
      // If user exists, proceed to the handler
      _log.info('Authentication check passed for user: ${user.id}');
      return handler(context.provide<User>(() => user));
    };
  };
}
