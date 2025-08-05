import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/response_helper.dart';
import 'package:logging/logging.dart';

// Logger for this handler.
final _logger = Logger('remote_config_handler');

// The well-known, constant ID for the singleton remote config document.
const _singletonId = 'default_config';

/// Handles requests for the singleton /api/v1/remote-config endpoint.
Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _handleGet(context);
    case HttpMethod.put:
      return _handlePut(context);
    default:
      // Other methods like POST, DELETE are not allowed on this singleton resource.
      // This is also enforced by the middleware.
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

/// Handles GET requests: Retrieves the singleton remote config.
Future<Response> _handleGet(RequestContext context) async {
  final repo = context.read<DataRepository<RemoteConfig>>();
  // Fetch the single configuration document using the well-known ID.
  final item = await repo.read(id: _singletonId);

  return ResponseHelper.success(
    context: context,
    data: item,
    toJsonT: (data) => data.toJson(),
  );
}

/// Handles PUT requests: Updates/replaces the singleton remote config.
Future<Response> _handlePut(RequestContext context) async {
  final requestBody = await context.request.json() as Map<String, dynamic>?;
  if (requestBody == null) {
    throw const BadRequestException('Missing or invalid request body.');
  }

  // Ensure the updatedAt timestamp is set for the update.
  requestBody['updatedAt'] = DateTime.now().toUtc().toIso8601String();

  RemoteConfig itemToUpdate;
  try {
    // The ID is always the singleton ID, so we inject it into the body
    // before deserialization to ensure the model is valid.
    requestBody['id'] = _singletonId;
    itemToUpdate = RemoteConfig.fromJson(requestBody);
  } on TypeError catch (e, s) {
    _logger.warning('Deserialization TypeError in PUT /remote-config', e, s);
    throw const BadRequestException(
      'Invalid request body: Missing or invalid required field(s).',
    );
  }

  final repo = context.read<DataRepository<RemoteConfig>>();
  final updatedItem = await repo.update(
    id: _singletonId,
    item: itemToUpdate,
  );

  return ResponseHelper.success(
    context: context,
    data: updatedItem,
    toJsonT: (data) => data.toJson(),
  );
}
