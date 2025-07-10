import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_shared/ht_shared.dart';

import '../../../_middleware.dart';

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

    // Create metadata, including the requestId from the context.
    final metadata = ResponseMetadata(
      requestId: context.read<RequestId>().id,
      timestamp: DateTime.now().toUtc(),
    );

    // Wrap the payload in the standard SuccessApiResponse
    final responsePayload = SuccessApiResponse<AuthSuccessResponse>(
      data: authPayload,
      metadata: metadata,
    );

    // Return 200 OK with the standardized, serialized response
    return Response.json(
      // Use the toJson method, providing the toJson factory for the inner type
      body: responsePayload.toJson((authSuccess) => authSuccess.toJson()),
    );
  } on HtHttpException catch (_) {
    // Let the central errorHandler middleware handle known exceptions
    rethrow;
  } catch (e) {
    // Catch unexpected errors from the service layer
    print('Unexpected error in /anonymous handler: $e');
    // Let the central errorHandler handle this as a 500
    throw const OperationFailedException(
      'An unexpected error occurred during anonymous sign-in.',
    );
  }
}
