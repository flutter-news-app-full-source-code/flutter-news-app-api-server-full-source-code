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

/// Handles requests for the /api/v1/users/{userId}/settings endpoint.
/// Currently only supports DELETE to clear all settings for the authenticated user.
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
    // This endpoint currently only supports DELETE
    if (context.request.method != HttpMethod.delete) {
      return Response(statusCode: HttpStatus.methodNotAllowed);
    }

    // Handle DELETE request, passing the authenticated user
    return await _handleDelete(context, authenticatedUser, requestId);
  } on HtHttpException catch (_) {
    // Let the errorHandler middleware handle HtHttpExceptions
    rethrow;
  } catch (e, stackTrace) {
    // Handle any other unexpected errors locally
    print(
      '[ReqID: $requestId] Unexpected error in /users/$userIdFromPath/settings/index.dart handler: $e\n$stackTrace',
    );
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: 'Internal Server Error.',
    );
  }
}

// --- DELETE Handler ---
Future<Response> _handleDelete(
  RequestContext context,
  User authenticatedUser, // Receive the authenticated user
  String requestId, // For logging
) async {
  // Read the HtAppSettingsClient to instantiate a user-scoped repository
  final settingsClient = context.read<HtAppSettingsClient>();
  final userSettingsRepo = HtAppSettingsRepository(
    client: settingsClient,
    userId: authenticatedUser.id, // Use the authenticated user's ID
  );

  // Call the repository method to clear settings.
  // Exceptions from the repository/client will propagate up.
  await userSettingsRepo.clearSettings();

  // Return 204 No Content on successful deletion
  return Response(statusCode: HttpStatus.noContent);
}
