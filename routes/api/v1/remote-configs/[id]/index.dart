import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/response_helper.dart';
import 'package:logging/logging.dart';

final _logger = Logger('remote_configs_item_handler');

/// Handles requests for the /api/v1/remote-configs/[id] endpoint.
/// This is treated as a singleton resource endpoint.
Future<Response> onRequest(RequestContext context, String id) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _handleGet(context, id);
    case HttpMethod.put:
      return _handlePut(context, id);
    default:
      // This should be caught by middleware, but as a safeguard:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

/// Handles GET requests: Retrieves a single remote config by its ID.
Future<Response> _handleGet(RequestContext context, String id) async {
  final repo = context.read<DataRepository<RemoteConfig>>();
  final item = await repo.read(id: id);

  return ResponseHelper.success(
    context: context,
    data: item,
    toJsonT: (data) => data.toJson(),
  );
}

/// Handles PUT requests: Updates an existing remote config by its ID.
Future<Response> _handlePut(RequestContext context, String id) async {
  final requestBody = await context.request.json() as Map<String, dynamic>?;
  if (requestBody == null) {
    throw const BadRequestException('Missing or invalid request body.');
  }

  requestBody['updatedAt'] = DateTime.now().toUtc().toIso8601String();

  RemoteConfig itemToUpdate;
  try {
    requestBody['id'] = id;
    itemToUpdate = RemoteConfig.fromJson(requestBody);
  } on TypeError catch (e, s) {
    _logger.warning('Deserialization TypeError in PUT /remote-configs/[id]', e, s);
    throw const BadRequestException(
      'Invalid request body: Missing or invalid required field(s).',
    );
  }

  final repo = context.read<DataRepository<RemoteConfig>>();
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
