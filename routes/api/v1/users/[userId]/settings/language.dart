//
// ignore_for_file: lines_longer_than_80_chars, avoid_catches_without_on_clauses

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_app_settings_client/ht_app_settings_client.dart'; // Added
import 'package:ht_app_settings_repository/ht_app_settings_repository.dart';
import 'package:ht_shared/ht_shared.dart';

// Import RequestId from the root middleware file
// Note: RequestId is provided by routes/_middleware.dart
// User is provided by authentication_middleware.dart via routes/api/v1/users/[userId]/settings/_middleware.dart
import '../../../../../_middleware.dart' show RequestId;

/// Handles requests for the /api/v1/users/{userId}/settings/language endpoint.
Future<Response> onRequest(
  RequestContext context,
  String userIdFromPath, // userId from the path parameter
) async {
  // Read dependencies provided by middleware
  final requestId = context.read<RequestId>().id;
  // User is guaranteed to be non-null by requireAuthentication middleware
  final authenticatedUser = context.read<User>();

  // Authorization: Ensure the userId in path matches the authenticated user
  if (userIdFromPath != authenticatedUser.id) {
    throw const ForbiddenException(
      'Access denied: You can only modify your own settings.',
    );
  }

  try {
    switch (context.request.method) {
      case HttpMethod.get:
        return await _handleGet(context, authenticatedUser, requestId);
      case HttpMethod.put:
        return await _handlePut(context, authenticatedUser, requestId);
      default:
        return Response(statusCode: HttpStatus.methodNotAllowed);
    }
  } on HtHttpException catch (_) {
    // Let the errorHandler middleware handle HtHttpExceptions
    rethrow;
  } on FormatException catch (_) {
    // Let the errorHandler middleware handle FormatExceptions (from PUT body)
    rethrow;
  } catch (e, stackTrace) {
    // Handle any other unexpected errors locally
    print(
      '[ReqID: $requestId] Unexpected error in /users/$userIdFromPath/settings/language.dart handler: $e\n$stackTrace',
    );
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: 'Internal Server Error.',
    );
  }
}

// --- GET Handler ---
Future<Response> _handleGet(
  RequestContext context,
  User authenticatedUser, // Receive the authenticated user
  String requestId,
) async {
  // Read the HtAppSettingsClient to instantiate a user-scoped repository
  final settingsClient = context.read<HtAppSettingsClient>();
  final userSettingsRepo = HtAppSettingsRepository(
    client: settingsClient,
    userId: authenticatedUser.id,
  );

  // Exceptions from repository will propagate up.
  final language = await userSettingsRepo.getLanguage();

  final metadata = ResponseMetadata(
    requestId: requestId,
    timestamp: DateTime.now().toUtc(),
  );

  // Wrap the language string in a simple map for consistency
  final responseData = {'language': language};

  final successResponse = SuccessApiResponse<Map<String, String>>(
    data: responseData,
    metadata: metadata,
  );

  // Need toJsonT for Map<String, String> (identity function works)
  final responseJson = successResponse.toJson((map) => map);

  return Response.json(body: responseJson);
}

// --- PUT Handler ---
Future<Response> _handlePut(
  RequestContext context,
  User authenticatedUser, // Receive the authenticated user
  String requestId,
) async {
  // Read the HtAppSettingsClient to instantiate a user-scoped repository
  final settingsClient = context.read<HtAppSettingsClient>();
  final userSettingsRepo = HtAppSettingsRepository(
    client: settingsClient,
    userId: authenticatedUser.id,
  );

  final requestBody = await context.request.json() as Map<String, dynamic>?;
  if (requestBody == null ||
      !requestBody.containsKey('language') ||
      requestBody['language'] is! String) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {
        'error': {
          'code': 'INVALID_REQUEST_BODY',
          'message':
              "Missing or invalid 'language' field in request body. Expected a string.",
        },
      },
    );
  }

  final newLanguage = requestBody['language'] as String;

  // Basic validation (e.g., length check, could add regex for ISO codes)
  if (newLanguage.isEmpty || newLanguage.length > 10) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {
        'error': {
          'code': 'INVALID_LANGUAGE_CODE',
          'message': 'Invalid language code format provided.',
        },
      },
    );
  }

  // Save the language. Repository exceptions will propagate up.
  await userSettingsRepo.setLanguage(newLanguage);

  // Optionally, return the updated language.
  final updatedLanguage = await userSettingsRepo.getLanguage();

  final metadata = ResponseMetadata(
    requestId: requestId,
    timestamp: DateTime.now().toUtc(),
  );

  final responseData = {'language': updatedLanguage};

  final successResponse = SuccessApiResponse<Map<String, String>>(
    data: responseData,
    metadata: metadata,
  );

  final responseJson = successResponse.toJson((map) => map);

  // Return 200 OK with the updated language
  return Response.json(body: responseJson);
}
