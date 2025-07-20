import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_shared/ht_shared.dart'; // For exceptions
import 'package:logging/logging.dart';

// Create a logger for this file.
final _logger = Logger('request_code_handler');

/// Handles POST requests to `/api/v1/auth/request-code`.
///
/// Initiates an email-based sign-in process. This endpoint is context-aware.
///
/// - For the user-facing app, it sends a verification code to the provided
///   email, supporting both sign-in and sign-up.
/// - For the dashboard, the request body must include `"isDashboardLogin": true`.
///   In this mode, it first verifies the user exists and has 'admin' or
///   'publisher' roles before sending a code, effectively acting as a
///   login-only gate.
Future<Response> onRequest(RequestContext context) async {
  // Ensure this is a POST request
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // Read the AuthService provided by middleware
  final authService = context.read<AuthService>();

  // Parse the request body
  final dynamic body;
  try {
    body = await context.request.json();
  } catch (_) {
    // Handle JSON parsing errors by throwing
    throw const InvalidInputException('Invalid JSON format in request body.');
  }

  if (body is! Map<String, dynamic>) {
    throw const InvalidInputException('Request body must be a JSON object.');
  }

  final email = body['email'] as String?;
  if (email == null || email.isEmpty) {
    throw const InvalidInputException(
      'Missing or empty "email" field in request body.',
    );
  }

  // Check for the optional dashboard login flag. This handles both boolean
  // `true` and string `"true"` values to prevent type cast errors.
  // It defaults to `false` if the key is missing or the value is not
  // recognized as true.
  final isDashboardLoginRaw = body['isDashboardLogin'];
  var isDashboardLogin = false;
  if (isDashboardLoginRaw is bool) {
    isDashboardLogin = isDashboardLoginRaw;
  } else if (isDashboardLoginRaw is String) {
    isDashboardLogin = isDashboardLoginRaw.toLowerCase() == 'true';
  }

  // Basic email format check (more robust validation can be added)
  // Using a slightly more common regex pattern
  final emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@"
    r'[a-zA-Z0-9]+\.[a-zA-Z]+',
  );
  if (!emailRegex.hasMatch(email)) {
    throw const InvalidInputException('Invalid email format provided.');
  }

  try {
    // Call the AuthService to handle the logic, passing the context flag.
    await authService.initiateEmailSignIn(
      email,
      isDashboardLogin: isDashboardLogin,
    );

    // Return 202 Accepted: The request is accepted for processing,
    // but the processing (email sending) hasn't necessarily completed.
    // 200 OK is also acceptable if you consider the API call itself complete.
    return Response(statusCode: HttpStatus.accepted);
  } on HtHttpException catch (_) {
    // Let the central errorHandler middleware handle known exceptions
    rethrow;
  } catch (e, s) {
    // Catch unexpected errors from the service layer
    _logger.severe('Unexpected error in /request-code handler', e, s);
    // Let the central errorHandler handle this as a 500
    throw const OperationFailedException(
      'An unexpected error occurred while requesting the sign-in code.',
    );
  }
}
