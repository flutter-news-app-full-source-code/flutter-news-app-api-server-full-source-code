import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/response_helper.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/user_preference_limit_service.dart';
import 'package:logging/logging.dart';

final _logger = Logger('user_preferences_handler');

/// Handles requests for the /api/v1/users/[id]/preferences endpoint.
///
/// This endpoint supports GET for retrieving a user's content preferences and
/// PUT for updating them.
Future<Response> onRequest(RequestContext context, String id) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _handleGet(context, id);
    case HttpMethod.put:
      return _handlePut(context, id);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

/// Handles GET requests: Retrieves UserContentPreferences by user ID.
Future<Response> _handleGet(RequestContext context, String id) async {
  final repo = context.read<DataRepository<UserContentPreferences>>();
  final item = await repo.read(id: id);

  return ResponseHelper.success(
    context: context,
    data: item,
    toJsonT: (data) => data.toJson(),
  );
}

/// Handles PUT requests: Updates an existing UserContentPreferences by user ID.
Future<Response> _handlePut(RequestContext context, String id) async {
  final requestBody = await context.request.json() as Map<String, dynamic>?;
  if (requestBody == null) {
    throw const BadRequestException('Missing or invalid request body.');
  }

  UserContentPreferences itemToUpdate;
  try {
    // Ensure the ID from the path is used, as it's the source of truth.
    requestBody['id'] = id;
    itemToUpdate = UserContentPreferences.fromJson(requestBody);
  } on TypeError catch (e, s) {
    _logger.warning('Deserialization TypeError in PUT /preferences', e, s);
    throw const BadRequestException(
      'Invalid request body: Missing or invalid required field(s).',
    );
  }

  // --- Business Logic: Enforce Preference Limits ---
  // Before updating, check if the new preferences exceed the user's limits.
  final user = context.read<User>(); // User is guaranteed by middleware
  final limitService = context.read<UserPreferenceLimitService>();
  await limitService.checkUpdatePreferences(user, itemToUpdate);

  // --- Data Persistence ---
  final repo = context.read<DataRepository<UserContentPreferences>>();
  final updatedItem = await repo.update(
    id: id,
    item: itemToUpdate,
  );

  return ResponseHelper.success(
    context: context,
    data: updatedItem,
    toJsonT: (data) => data.toJson(),
  );
}
