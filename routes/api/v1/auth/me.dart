import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/response_helper.dart';

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

  // Use the helper to create a standardized success response
  return ResponseHelper.success(
    context: context,
    data: user,
    toJsonT: (data) => data.toJson(),
  );
}
