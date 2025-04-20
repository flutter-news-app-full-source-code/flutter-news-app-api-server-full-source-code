import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_countries_client/ht_countries_client.dart'; // Import client exceptions

/// Creates a JSON response for errors.
Response _errorResponse(int statusCode, String message) {
  return Response.json(
    statusCode: statusCode,
    body: {'error': message},
  );
}

/// Middleware to handle common exceptions and return standardized error
/// responses.
///
/// This middleware should be placed early in the middleware chain, typically
/// after logging but before route-specific logic, to catch errors effectively.
Middleware errorHandler() {
  return (handler) {
    return (context) async {
      try {
        // Attempt to execute the rest of the handler chain.
        final response = await handler(context);
        return response;
      } on FormatException catch (e, stackTrace) {
        // Handle errors related to invalid request data format
        // (e.g., bad JSON).
        print('FormatException caught: $e\n$stackTrace'); // Log for debugging
        return _errorResponse(
          HttpStatus.badRequest, // 400
          'Invalid request format: ${e.message}',
        );
      } on CountryNotFound catch (e, stackTrace) {
        // Handle cases where a requested country resource doesn't exist.
        print('CountryNotFound caught: $e\n$stackTrace'); // Log for debugging
        return _errorResponse(
          HttpStatus.notFound, // 404
          'Country not found: ${e.error}', // Use the underlying error message
        );
      } on CountryFetchFailure catch (e, stackTrace) {
        // Handle generic failures during country data fetching.
        print(
          'CountryFetchFailure caught: $e\n$stackTrace',
        ); // Log for debugging
        return _errorResponse(
          HttpStatus.internalServerError, // 500
          'Failed to fetch country data: ${e.error}',
        );
      } on CountryCreateFailure catch (e, stackTrace) {
        // Handle failures during country creation.
        print(
          'CountryCreateFailure caught: $e\n$stackTrace',
        ); // Log for debugging
        // Could potentially be a 409 Conflict if it's a duplicate,
        // but 500 is safer default if the cause is unknown.
        return _errorResponse(
          HttpStatus.internalServerError, // 500
          'Failed to create country: ${e.error}',
        );
      } on CountryUpdateFailure catch (e, stackTrace) {
        // Handle failures during country update.
        print(
          'CountryUpdateFailure caught: $e\n$stackTrace',
        ); // Log for debugging
        return _errorResponse(
          HttpStatus.internalServerError, // 500
          'Failed to update country: ${e.error}',
        );
      } on CountryDeleteFailure catch (e, stackTrace) {
        // Handle failures during country deletion.
        print(
          'CountryDeleteFailure caught: $e\n$stackTrace',
        ); // Log for debugging
        return _errorResponse(
          HttpStatus.internalServerError, // 500
          'Failed to delete country: ${e.error}',
        );
      } catch (e, stackTrace) {
        // Catch any other unexpected errors.
        print(
          'Unhandled exception caught: $e\n$stackTrace',
        ); // Log for debugging
        return _errorResponse(
          HttpStatus.internalServerError, // 500
          'An unexpected server error occurred.',
        );
      }
    };
  };
}
