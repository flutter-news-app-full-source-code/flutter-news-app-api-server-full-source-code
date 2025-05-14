import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_app_settings_client/ht_app_settings_client.dart';
import 'package:ht_app_settings_repository/ht_app_settings_repository.dart';
import 'package:ht_shared/ht_shared.dart';

import '../../../../../_middleware.dart' show RequestId;

/// Handles requests for the /api/v1/users/{userId}/settings/display endpoint.
Future<Response> onRequest(
  RequestContext context,
  String userIdFromPath,
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
      '[ReqID: $requestId] Unexpected error in /users/$userIdFromPath/settings/display.dart handler: $e\n$stackTrace',
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
  User authenticatedUser,
  String requestId,
) async {
  // Read the HtAppSettingsClient to instantiate a user-scoped repository
  final settingsClient = context.read<HtAppSettingsClient>();
  final userSettingsRepo = HtAppSettingsRepository(
    client: settingsClient,
    userId: authenticatedUser.id,
  );

  // Exceptions from repository (e.g., client failure) will propagate up.
  final displaySettings = await userSettingsRepo.getDisplaySettings();

  final metadata = ResponseMetadata(
    requestId: requestId,
    timestamp: DateTime.now().toUtc(),
  );

  final successResponse = SuccessApiResponse<DisplaySettings>(
    data: displaySettings,
    metadata: metadata,
  );

  // Use the generated toJson method for DisplaySettings
  final responseJson = successResponse.toJson((settings) => settings.toJson());

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
  if (requestBody == null) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Missing or invalid request body.',
    );
  }

  // Deserialize request body into DisplaySettings.
  // FormatException or TypeError during parsing will propagate up.
  final newSettings = DisplaySettings.fromJson(requestBody);

  // Save the settings. Repository exceptions will propagate up.
  await userSettingsRepo.setDisplaySettings(newSettings);

  // Optionally, return the updated settings.
  // Fetching again ensures we return the exact state after saving.
  final updatedSettings = await userSettingsRepo.getDisplaySettings();

  final metadata = ResponseMetadata(
    requestId: requestId,
    timestamp: DateTime.now().toUtc(),
  );

  final successResponse = SuccessApiResponse<DisplaySettings>(
    data: updatedSettings,
    metadata: metadata,
  );

  final responseJson = successResponse.toJson((settings) => settings.toJson());

  // Return 200 OK with the updated settings
  return Response.json(body: responseJson);
}
