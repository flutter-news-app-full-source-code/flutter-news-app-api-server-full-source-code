import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_service.dart';
import 'package:logging/logging.dart';

// Create a logger for this file.
final _logger = Logger('sign_out_handler');

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

  // Extract the current token from the Authorization header
  final authHeader = context.request.headers[HttpHeaders.authorizationHeader];
  String? token;
  if (authHeader != null && authHeader.startsWith('Bearer ')) {
    token = authHeader.substring(7);
  }

  // Although authentication middleware should ensure a token is present,
  // this check acts as a safeguard.
  if (token == null || token.isEmpty) {
    _logger.severe(
      'Could not extract Bearer token for user ${user.id} in sign-out handler.',
    );
    throw const OperationFailedException(
      'Internal error: Unable to retrieve authentication token for sign-out.',
    );
  }

  // Read the AuthService provided by middleware
  final authService = context.read<AuthService>();

  try {
    // Call the AuthService to handle any server-side sign-out logic,
    // including token invalidation.
    await authService.performSignOut(userId: user.id, token: token);

    // Return 204 No Content indicating successful sign-out action
    return Response(statusCode: HttpStatus.noContent);
  } on HttpException catch (_) {
    // Let the central errorHandler middleware handle known exceptions
    rethrow;
  } catch (e, s) {
    // Catch unexpected errors from the service layer
    _logger.severe(
      'Unexpected error in /sign-out handler for user ${user.id}',
      e,
      s,
    );
    // Let the central errorHandler handle this as a 500
    throw const OperationFailedException(
      'An unexpected error occurred during sign-out.',
    );
  }
}
