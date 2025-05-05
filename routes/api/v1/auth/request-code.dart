import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_shared/ht_shared.dart'; // For exceptions

/// Handles POST requests to `/api/v1/auth/request-code`.
///
/// Initiates the email sign-in process by requesting a verification code
/// be sent to the provided email address.
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
    // Call the AuthService to handle the logic
    await authService.initiateEmailSignIn(email);

    // Return 202 Accepted: The request is accepted for processing,
    // but the processing (email sending) hasn't necessarily completed.
    // 200 OK is also acceptable if you consider the API call itself complete.
    return Response(statusCode: HttpStatus.accepted);
  } on HtHttpException catch (_) {
    // Let the central errorHandler middleware handle known exceptions
    rethrow;
  } catch (e) {
    // Catch unexpected errors from the service layer
    print('Unexpected error in /request-code handler: $e');
    // Let the central errorHandler handle this as a 500
    throw const OperationFailedException(
      'An unexpected error occurred while requesting the sign-in code.',
    );
  }
}
