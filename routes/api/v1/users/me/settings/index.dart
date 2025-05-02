//
// ignore_for_file: lines_longer_than_80_chars, avoid_catches_without_on_clauses

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_app_settings_repository/ht_app_settings_repository.dart';
import 'package:ht_shared/ht_shared.dart';

// Import RequestId from the root middleware file
import '../../../../../_middleware.dart';

/// Handles requests for the base /api/v1/users/me/settings endpoint.
/// Currently only supports DELETE to clear all settings.
Future<Response> onRequest(RequestContext context) async {
  // Read dependencies provided by middleware
  final settingsRepo = context.read<HtAppSettingsRepository>();
  final requestId = context.read<RequestId>().id;

  try {
    // This endpoint currently only supports DELETE
    if (context.request.method != HttpMethod.delete) {
      return Response(statusCode: HttpStatus.methodNotAllowed);
    }

    // Handle DELETE request
    return await _handleDelete(context, settingsRepo, requestId);
  } on HtHttpException catch (_) {
    // Let the errorHandler middleware handle HtHttpExceptions
    rethrow;
  } catch (e, stackTrace) {
    // Handle any other unexpected errors locally
    print(
      '[ReqID: $requestId] Unexpected error in /settings/index.dart handler: $e\n$stackTrace',
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
  HtAppSettingsRepository settingsRepo,
  String requestId,
) async {
  // Call the repository method to clear settings.
  // Exceptions from the repository/client will propagate up.
  await settingsRepo.clearSettings();

  // Return 204 No Content on successful deletion
  return Response(statusCode: HttpStatus.noContent);
}
