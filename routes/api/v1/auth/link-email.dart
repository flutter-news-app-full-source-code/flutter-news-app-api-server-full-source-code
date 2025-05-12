import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_shared/ht_shared.dart'; // For User and exceptions

/// Handles POST requests to `/api/v1/auth/link-email`.
///
/// Allows an authenticated anonymous user to initiate the process of linking
/// an email address to their account to make it permanent.
Future<Response> onRequest(RequestContext context) async {
  // 1. Ensure this is a POST request
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // 2. Read the authenticated User from context (provided by middleware)
  final authenticatedUser = context.read<User?>();

  // 3. Validate that an authenticated user exists and is anonymous
  if (authenticatedUser == null) {
    // This should ideally be caught by `authenticationProvider` if route is protected
    throw const UnauthorizedException('Authentication required to link email.');
  }
  if (!authenticatedUser.isAnonymous) {
    throw const BadRequestException(
      'Account is already permanent. Cannot initiate email linking.',
    );
  }

  // 4. Read the AuthService
  final authService = context.read<AuthService>();

  // 5. Parse the request body for the email to link
  final dynamic body;
  try {
    body = await context.request.json();
  } catch (_) {
    throw const InvalidInputException('Invalid JSON format in request body.');
  }

  if (body is! Map<String, dynamic>) {
    throw const InvalidInputException('Request body must be a JSON object.');
  }

  final emailToLink = body['email'] as String?;
  if (emailToLink == null || emailToLink.isEmpty) {
    throw const InvalidInputException(
      'Missing or empty "email" field in request body.',
    );
  }

  // Basic email format validation
  final emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@"
    r'[a-zA-Z0-9]+\.[a-zA-Z]+',
  );
  if (!emailRegex.hasMatch(emailToLink)) {
    throw const InvalidInputException('Invalid email format provided.');
  }

  // 6. Call AuthService to initiate the linking process
  try {
    await authService.initiateLinkEmailProcess(
      anonymousUser: authenticatedUser,
      emailToLink: emailToLink,
    );

    // Return 202 Accepted: The request is accepted for processing.
    return Response(statusCode: HttpStatus.accepted);
  } on HtHttpException catch (_) {
    // Let the central errorHandler middleware handle known exceptions
    rethrow;
  } catch (e) {
    // Catch unexpected errors from the service layer
    print(
      'Unexpected error in /link-email handler for user ${authenticatedUser.id}: $e',
    );
    throw OperationFailedException(
      'An unexpected error occurred while initiating email linking: ${e.toString()}',
    );
  }
}
