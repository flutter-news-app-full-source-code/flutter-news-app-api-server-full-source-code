import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/response_helper.dart';
import 'package:logging/logging.dart';

final _logger = Logger('user_settings_handler');

/// Handles requests for the /api/v1/users/[id]/settings endpoint.
///
/// This endpoint supports GET for retrieving a user's app settings and
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

/// Handles GET requests: Retrieves UserAppSettings by user ID.
Future<Response> _handleGet(RequestContext context, String id) async {
  final repo = context.read<DataRepository<UserAppSettings>>();
  final item = await repo.read(id: id);

  return ResponseHelper.success(
    context: context,
    data: item,
    toJsonT: (data) => data.toJson(),
  );
}

/// Handles PUT requests: Updates an existing UserAppSettings by user ID.
Future<Response> _handlePut(RequestContext context, String id) async {
  final requestBody = await context.request.json() as Map<String, dynamic>?;
  if (requestBody == null) {
    throw const BadRequestException('Missing or invalid request body.');
  }

  // Note: Timestamps for settings are not typically updated on every change.
  // If they were, you would add `updatedAt` here.

  UserAppSettings itemToUpdate;
  try {
    // Ensure the ID from the path is used, as it's the source of truth.
    requestBody['id'] = id;
    itemToUpdate = UserAppSettings.fromJson(requestBody);
  } on TypeError catch (e, s) {
    _logger.warning('Deserialization TypeError in PUT /settings', e, s);
    throw const BadRequestException(
      'Invalid request body: Missing or invalid required field(s).',
    );
  }

  // The ID check is implicitly handled by setting it from the path parameter.

  final repo = context.read<DataRepository<UserAppSettings>>();
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
