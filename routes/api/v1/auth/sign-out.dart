import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_shared/ht_shared.dart'; // For User and exceptions

/// Handles POST requests to `/api/v1/auth/sign-out`.
///
/// Performs server-side sign-out actions if necessary (e.g., token
/// invalidation). Requires authentication middleware to run first.
Future<Response> onRequest(RequestContext context) async {
  // Ensure this is a POST request
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // Read the User object provided by the authentication middleware.
  // A user must be authenticated to sign out.
  final user = context.read<User?>();

  // Use requireAuthentication middleware before this route to handle this check.
  // This check is a safeguard.
  if (user == null) {
    throw const UnauthorizedException('Authentication required to sign out.');
  }

  // Read the AuthService provided by middleware
  final authService = context.read<AuthService>();

  try {
    // Call the AuthService to handle any server-side sign-out logic
    await authService.performSignOut(userId: user.id);

    // Return 204 No Content indicating successful sign-out action
    return Response(statusCode: HttpStatus.noContent);
  } on HtHttpException catch (_) {
    // Let the central errorHandler middleware handle known exceptions
    // (though performSignOut might not throw many specific ones)
    rethrow;
  } catch (e) {
    // Catch unexpected errors from the service layer
    print('Unexpected error in /sign-out handler for user ${user.id}: $e');
    // Let the central errorHandler handle this as a 500
    throw const OperationFailedException(
      'An unexpected error occurred during sign-out.',
    );
  }
}
