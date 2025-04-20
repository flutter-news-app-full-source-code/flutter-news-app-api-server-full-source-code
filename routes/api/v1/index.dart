import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

/// Handles requests to the root path (`/`).
///
/// Returns a simple welcome message indicating the API is running.
Response onRequest(RequestContext context) {
  // You could potentially add more information here
  // like links to documentation.
  return Response.json(
    statusCode: HttpStatus.ok, // 200
    body: {'message': 'Welcome to the Headlines Toolkit API V1!'},
  );
}
