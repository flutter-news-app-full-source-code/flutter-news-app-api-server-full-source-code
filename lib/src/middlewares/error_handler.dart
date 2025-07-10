//
// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_shared/ht_shared.dart';

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
        final errorCode = _mapExceptionToCodeString(e);
        print('HtHttpException Caught: $e\n$stackTrace'); // Log for debugging
        return Response.json(
          statusCode: statusCode,
          body: {
            'error': {'code': errorCode, 'message': e.message},
          },
        );
      } on FormatException catch (e, stackTrace) {
        // Handle data format/parsing errors (often indicates bad client input)
        print('FormatException Caught: $e\n$stackTrace'); // Log for debugging
        return Response.json(
          statusCode: HttpStatus.badRequest, // 400
          body: {
            'error': {
              'code': 'invalidFormat',
              'message': 'Invalid data format: ${e.message}',
            },
          },
        );
      } catch (e, stackTrace) {
        // Handle any other unexpected errors
        print('Unhandled Exception Caught: $e\n$stackTrace');
        return Response.json(
          statusCode: HttpStatus.internalServerError, // 500
          body: {
            'error': {
              'code': 'internalServerError',
              'message': 'An unexpected internal server error occurred.',
              // Avoid leaking sensitive details in production responses
              // 'details': e.toString(), // Maybe include in dev mode only
            },
          },
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
