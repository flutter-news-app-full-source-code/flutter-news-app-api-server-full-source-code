import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_shared/ht_shared.dart'; // For User, AuthSuccessResponse, exceptions

/// Handles POST requests to `/api/v1/auth/verify-link-email`.
///
/// Allows an authenticated anonymous user to complete the email linking process
/// by providing the verification code sent to their email.
Future<Response> onRequest(RequestContext context) async {
  // 1. Ensure this is a POST request
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // 2. Read the authenticated User from context (provided by middleware)
  final authenticatedUser = context.read<User?>();

  // 3. Validate that an authenticated user exists and is anonymous
  if (authenticatedUser == null) {
    throw const UnauthorizedException(
      'Authentication required to verify email link.',
    );
  }
  if (!authenticatedUser.isAnonymous) {
    throw const BadRequestException(
      'Account is already permanent. Cannot complete email linking.',
    );
  }

  // 4. Extract the current (old) anonymous token for invalidation
  final authHeader = context.request.headers[HttpHeaders.authorizationHeader];
  String? oldAnonymousToken;
  if (authHeader != null && authHeader.startsWith('Bearer ')) {
    oldAnonymousToken = authHeader.substring(7);
  }
  if (oldAnonymousToken == null || oldAnonymousToken.isEmpty) {
    // This should not happen if authentication middleware ran successfully
    // and the user is indeed authenticated.
    print(
      'Error: Could not extract Bearer token for user ${authenticatedUser.id} in verify-link-email.',
    );
    throw const OperationFailedException(
      'Internal error: Unable to retrieve current authentication token for invalidation.',
    );
  }

  // 5. Read the AuthService
  final authService = context.read<AuthService>();

  // 6. Parse the request body for the verification code
  final dynamic body;
  try {
    body = await context.request.json();
  } catch (_) {
    throw const InvalidInputException('Invalid JSON format in request body.');
  }

  if (body is! Map<String, dynamic>) {
    throw const InvalidInputException('Request body must be a JSON object.');
  }

  final codeFromUser = body['code'] as String?;
  if (codeFromUser == null || codeFromUser.isEmpty) {
    throw const InvalidInputException(
      'Missing or empty "code" field in request body.',
    );
  }
  // Basic code format validation (e.g., 6 digits)
  if (!RegExp(r'^\d{6}$').hasMatch(codeFromUser)) {
    throw const InvalidInputException(
      'Invalid code format. Code must be 6 digits.',
    );
  }

  // 7. Call AuthService to complete the linking process
  try {
    final result = await authService.completeLinkEmailProcess(
      anonymousUser: authenticatedUser,
      codeFromUser: codeFromUser,
      oldAnonymousToken: oldAnonymousToken,
    );

    // Create the specific payload containing user and token
    final authPayload = AuthSuccessResponse(
      user: result.user,
      token: result.token,
    );

    // Wrap the payload in the standard SuccessApiResponse
    final responsePayload = SuccessApiResponse<AuthSuccessResponse>(
      data: authPayload,
      // metadata: ResponseMetadata(timestamp: DateTime.now().toUtc()),
    );

    // Return 200 OK with the standardized, serialized response
    return Response.json(
      body: responsePayload.toJson((authSuccess) => authSuccess.toJson()),
    );
  } on HtHttpException catch (_) {
    rethrow;
  } catch (e) {
    print(
      'Unexpected error in /verify-link-email handler for user ${authenticatedUser.id}: $e',
    );
    throw OperationFailedException(
      'An unexpected error occurred while verifying email link: ${e.toString()}',
    );
  }
}
