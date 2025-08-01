import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/response_helper.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_service.dart';
import 'package:logging/logging.dart';

// Create a logger for this file.
final _logger = Logger('anonymous_handler');

/// Handles POST requests to `/api/v1/auth/anonymous`.
///
/// Creates a new anonymous user and returns the User object along with an
/// authentication token.
Future<Response> onRequest(RequestContext context) async {
  // Ensure this is a POST request
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // Read the AuthService provided by middleware
  final authService = context.read<AuthService>();

  try {
    // Call the AuthService to handle anonymous sign-in logic
    final result = await authService.performAnonymousSignIn();

    // Create the specific payload containing user and token
    final authPayload = AuthSuccessResponse(
      user: result.user,
      token: result.token,
    );

    // Use the helper to create a standardized success response
    return ResponseHelper.success(
      context: context,
      data: authPayload,
      toJsonT: (data) => data.toJson(),
    );
  } on HttpException catch (_) {
    // Let the central errorHandler middleware handle known exceptions
    rethrow;
  } catch (e, s) {
    // Catch unexpected errors from the service layer
    _logger.severe('Unexpected error in /anonymous handler', e, s);
    // Let the central errorHandler handle this as a 500
    throw const OperationFailedException(
      'An unexpected error occurred during anonymous sign-in.',
    );
  }
}
