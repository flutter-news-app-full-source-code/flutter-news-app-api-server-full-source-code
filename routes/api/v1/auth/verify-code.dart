import 'dart:io';

// Import exceptions, User, SuccessApiResponse, AND AuthSuccessResponse
import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/helpers/response_helper.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/auth_service.dart';
import 'package:logging/logging.dart';

// Create a logger for this file.
final _logger = Logger('verify_code_handler');

/// Handles POST requests to `/api/v1/auth/verify-code`.
///
/// Verifies the provided email and code, completes the sign-in/sign-up,
/// and returns the authenticated User object along with an auth token. It
/// supports a context-aware flow by checking for an `isDashboardLogin`
/// flag in the request body, which dictates whether to perform a strict
/// login-only check or a standard sign-in/sign-up.
Future<Response> onRequest(RequestContext context) async {
  // Ensure this is a POST request
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // Read the AuthService and the currently authenticated user from middleware.
  final authService = context.read<AuthService>();
  final authenticatedUser = context.read<User?>();

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

  // Extract and validate email
  final email = body['email'] as String?;
  if (email == null || email.isEmpty) {
    throw const InvalidInputException(
      'Missing or empty "email" field in request body.',
    );
  }
  // Using a slightly more common regex pattern
  final emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@"
    r'[a-zA-Z0-9]+\.[a-zA-Z]+',
  );
  if (!emailRegex.hasMatch(email)) {
    throw const InvalidInputException('Invalid email format provided.');
  }

  // Extract and validate code
  final code = body['code'] as String?;
  if (code == null || code.isEmpty) {
    throw const InvalidInputException(
      'Missing or empty "code" field in request body.',
    );
  }
  // Basic validation (e.g., check if it's 6 digits)
  if (!RegExp(r'^\d{6}$').hasMatch(code)) {
    throw const InvalidInputException(
      'Invalid code format. Code must be 6 digits.',
    );
  }

  // Check for the optional dashboard login flag. Default to false.
  final isDashboardLogin = (body['isDashboardLogin'] as bool?) ?? false;

  // Extract the current token from the Authorization header, if it exists.
  // This is needed for the guest-to-permanent flow to invalidate the old token.
  final authHeader = context.request.headers[HttpHeaders.authorizationHeader];
  String? currentToken;
  if (authHeader != null && authHeader.startsWith('Bearer ')) {
    currentToken = authHeader.substring(7);
  }

  try {
    // Call the AuthService to handle the verification and sign-in logic.
    // Pass the authenticatedUser to allow for anonymous-to-permanent account
    // conversion, and the currentToken for invalidation.
    final result = await authService.completeEmailSignIn(
      email,
      code,
      isDashboardLogin: isDashboardLogin,
      authenticatedUser: authenticatedUser,
      currentToken: currentToken,
    );

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
    // (e.g., InvalidInputException if code is wrong/expired)
    rethrow;
  } catch (e, s) {
    // Catch unexpected errors from the service layer
    _logger.severe('Unexpected error in /verify-code handler', e, s);
    // Let the central errorHandler handle this as a 500
    throw const OperationFailedException(
      'An unexpected error occurred while verifying the sign-in code.',
    );
  }
}
