import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
// To read RequestId if needed
import 'package:ht_shared/ht_shared.dart'; // For User, SuccessApiResponse etc.

import '../../../_middleware.dart'; // Potentially for RequestId definition

/// Handles GET requests to `/api/v1/auth/me`.
///
/// Retrieves the details of the currently authenticated user based on the
/// provided Bearer token. Requires authentication middleware to run first.
/// Returns the user data wrapped in a [SuccessApiResponse].
Future<Response> onRequest(RequestContext context) async {
  // Ensure this is a GET request
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // Read the User object provided by the authentication middleware.
  // The `requireAuthentication` middleware (applied later) should ensure
  // this is not null by the time the handler runs.
  final user = context.read<User?>();

  // This check is technically redundant if requireAuthentication middleware
  // is correctly applied before this route, but serves as a safeguard.
  if (user == null) {
    // This should ideally be caught by requireAuthentication middleware first.
    // Throwing allows the central error handler to format the 401 response.
    throw const UnauthorizedException('Authentication required.');
  }

  // Create metadata. Include requestId if it's available in context.
  // Note: Need to ensure RequestId is provided globally or adjust accordingly.
  String? requestId;
  try {
    // Attempt to read RequestId, handle gracefully if not provided at this level
    requestId = context.read<RequestId>().id;
  } catch (_) {
    // RequestId might not be provided directly in this context scope
    print('RequestId not found in context for /auth/me');
  }

  final metadata = ResponseMetadata(
    requestId: requestId,
    timestamp: DateTime.now().toUtc(),
  );

  // Wrap the user data in SuccessApiResponse
  final responsePayload = SuccessApiResponse<User>(
    data: user,
    metadata: metadata,
  );

  // Return 200 OK with the wrapped and serialized response
  return Response.json(
    body: responsePayload.toJson((user) => user.toJson()),
  );
}
