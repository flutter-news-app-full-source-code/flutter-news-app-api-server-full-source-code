import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_service.dart';
import 'package:logging/logging.dart';

// Create a logger for this file.
final _logger = Logger('delete_account_handler');

/// Handles DELETE requests to `/api/v1/auth/delete-account`.
///
/// Allows an authenticated user to delete their account.
/// Requires authentication middleware to run first.
Future<Response> onRequest(RequestContext context) async {
  // Ensure this is a DELETE request
  if (context.request.method != HttpMethod.delete) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // Read the User object provided by the authentication middleware.
  // A user must be authenticated to delete their account.
  final user = context.read<User?>();

  // Use requireAuthentication middleware before this route to handle this check.
  // This check is a safeguard.
  if (user == null) {
    throw const UnauthorizedException(
      'Authentication required to delete account.',
    );
  }

  // Read the AuthService provided by middleware
  final authService = context.read<AuthService>();

  try {
    // Call the AuthService to handle account deletion logic
    await authService.deleteAccount(userId: user.id);

    // Return 204 No Content indicating successful deletion
    return Response(statusCode: HttpStatus.noContent);
  } on HttpException catch (_) {
    // Let the central errorHandler middleware handle known exceptions
    rethrow;
  } catch (e, s) {
    // Catch unexpected errors from the service layer
    _logger.severe(
      'Unexpected error in /delete-account handler for user ${user.id}',
      e,
      s,
    );
    // Let the central errorHandler handle this as a 500
    throw const OperationFailedException(
      'An unexpected error occurred during account deletion.',
    );
  }
}
