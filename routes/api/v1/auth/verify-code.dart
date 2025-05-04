import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_shared/ht_shared.dart'; // For exceptions and models

/// Handles POST requests to `/api/v1/auth/verify-code`.
///
/// Verifies the provided email and code, completes the sign-in/sign-up,
/// and returns the authenticated User object along with an auth token.
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
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Invalid JSON format in request body.',
    );
  }

  if (body is! Map<String, dynamic>) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Request body must be a JSON object.',
    );
  }

  // Extract and validate email
  final email = body['email'] as String?;
  if (email == null || email.isEmpty) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Missing or empty "email" field in request body.',
    );
  }
  if (!RegExp(r'^.+@.+\..+$').hasMatch(email)) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Invalid email format provided.',
    );
  }

  // Extract and validate code
  final code = body['code'] as String?;
  if (code == null || code.isEmpty) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Missing or empty "code" field in request body.',
    );
  }
  // Basic validation (e.g., check if it's 6 digits)
  if (!RegExp(r'^\d{6}$').hasMatch(code)) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Invalid code format. Code must be 6 digits.',
    );
  }

  try {
    // Call the AuthService to handle the verification and sign-in logic
    final result = await authService.completeEmailSignIn(email, code);

    // Return 200 OK with the user and token
    return Response.json(
      body: {
        'user': result.user.toJson(), // Serialize the User object
        'token': result.token,
      },
    );
  } on HtHttpException catch (_) {
    // Let the central errorHandler middleware handle known exceptions
    // (e.g., InvalidInputException if code is wrong/expired)
    rethrow;
  } catch (e) {
    // Catch unexpected errors from the service layer
    print('Unexpected error in /verify-code handler: $e');
    // Let the central errorHandler handle this as a 500
    throw const OperationFailedException(
      'An unexpected error occurred while verifying the sign-in code.',
    );
  }
}
