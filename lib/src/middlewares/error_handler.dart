//
// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:json_annotation/json_annotation.dart';

/// Middleware that catches errors and converts them into
/// standardized JSON responses.
Middleware errorHandler() {
  return (handler) {
    return (context) async {
      try {
        // Attempt to execute the request handler
        final response = await handler(context);
        return response;
      } on HtHttpException catch (e, stackTrace) {
        // Handle specific HtHttpExceptions from the client/repository layers
        final statusCode = _mapExceptionToStatusCode(e);
        print('HtHttpException Caught: $e\n$stackTrace'); // Log for debugging
        return _jsonErrorResponse(
          statusCode: statusCode,
          exception: e,
          context: context,
        );
      } on CheckedFromJsonException catch (e, stackTrace) {
        // Handle json_serializable validation errors. These are client errors.
        final field = e.key ?? 'unknown';
        final message = 'Invalid request body: Field "$field" has an '
            'invalid value or is missing. ${e.message}';
        print('CheckedFromJsonException Caught: $e\n$stackTrace');
        return _jsonErrorResponse(
          statusCode: HttpStatus.badRequest, // 400
          exception: InvalidInputException(message),
          context: context,
        );
      } on FormatException catch (e, stackTrace) {
        // Handle data format/parsing errors (often indicates bad client input)
        print('FormatException Caught: $e\n$stackTrace'); // Log for debugging
        return _jsonErrorResponse(
          statusCode: HttpStatus.badRequest, // 400
          exception: InvalidInputException('Invalid data format: ${e.message}'),
          context: context,
        );
      } catch (e, stackTrace) {
        // Handle any other unexpected errors
        print('Unhandled Exception Caught: $e\n$stackTrace');
        return _jsonErrorResponse(
          statusCode: HttpStatus.internalServerError, // 500
          exception: const UnknownException('An unexpected internal server error occurred.'),
          context: context,
        );
      }
    };
  };
}

/// Maps HtHttpException subtypes to appropriate HTTP status codes.
int _mapExceptionToStatusCode(HtHttpException exception) {
  return switch (exception) {
    InvalidInputException() => HttpStatus.badRequest, // 400
    AuthenticationException() => HttpStatus.unauthorized, // 401
    BadRequestException() => HttpStatus.badRequest, // 400
    UnauthorizedException() => HttpStatus.unauthorized, // 401
    ForbiddenException() => HttpStatus.forbidden, // 403
    NotFoundException() => HttpStatus.notFound, // 404
    ServerException() => HttpStatus.internalServerError, // 500
    OperationFailedException() => HttpStatus.internalServerError, // 500
    NetworkException() => HttpStatus.serviceUnavailable, // 503 (or 500)
    ConflictException() => HttpStatus.conflict, // 409
    UnknownException() => HttpStatus.internalServerError, // 500
    _ => HttpStatus.internalServerError, // Default
  };
}

/// Maps HtHttpException subtypes to consistent error code strings.
String _mapExceptionToCodeString(HtHttpException exception) {
  return switch (exception) {
    InvalidInputException() => 'invalidInput',
    AuthenticationException() => 'authenticationFailed',
    BadRequestException() => 'badRequest',
    UnauthorizedException() => 'unauthorized',
    ForbiddenException() => 'forbidden',
    NotFoundException() => 'notFound',
    ServerException() => 'serverError',
    OperationFailedException() => 'operationFailed',
    NetworkException() => 'networkError',
    ConflictException() => 'conflict',
    UnknownException() => 'unknownError',
    _ => 'unknownError', // Default
  };
}

/// Creates a standardized JSON error response with appropriate CORS headers.
///
/// This helper ensures that error responses sent to the client include the
/// necessary `Access-Control-Allow-Origin` header, allowing the client-side
/// application to read the error message body.
Response _jsonErrorResponse({
  required int statusCode,
  required HtHttpException exception,
  required RequestContext context,
}) {
  final errorCode = _mapExceptionToCodeString(exception);
  final headers = <String, String>{
    HttpHeaders.contentTypeHeader: 'application/json',
  };

  // Add CORS headers to error responses to allow the client to read them.
  // This logic mirrors the behavior of `shelf_cors_headers` for development.
  final origin = context.request.headers['Origin'];
  if (origin != null) {
    // A simple check for localhost development environments.
    // For production, this should be a more robust check against a list
    // of allowed origins from environment variables.
    if (Uri.tryParse(origin)?.host == 'localhost') {
      headers[HttpHeaders.accessControlAllowOriginHeader] = origin;
      headers[HttpHeaders.accessControlAllowMethodsHeader] =
          'GET, POST, PUT, DELETE, OPTIONS';
      headers[HttpHeaders.accessControlAllowHeadersHeader] =
          'Origin, Content-Type, Authorization';
    }
  }

  return Response.json(
    statusCode: statusCode,
    body: {'error': {'code': errorCode, 'message': exception.message}},
    headers: headers,
  );
}
