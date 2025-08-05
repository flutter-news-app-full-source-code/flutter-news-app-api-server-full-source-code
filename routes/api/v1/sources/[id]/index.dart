import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/response_helper.dart';
import 'package:logging/logging.dart';

final _logger = Logger('sources_item_handler');

/// Handles requests for the /api/v1/sources/[id] endpoint.
///
/// This endpoint supports GET for retrieving a single source, PUT for updating
/// a source, and DELETE for removing a source.
Future<Response> onRequest(RequestContext context, String id) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _handleGet(context, id);
    case HttpMethod.put:
      return _handlePut(context, id);
    case HttpMethod.delete:
      return _handleDelete(context, id);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

/// Handles GET requests: Retrieves a single source by its ID.
Future<Response> _handleGet(RequestContext context, String id) async {
  final repo = context.read<DataRepository<Source>>();
  final item = await repo.read(id: id);

  return ResponseHelper.success(
    context: context,
    data: item,
    toJsonT: (data) => (data as dynamic).toJson() as Map<String, dynamic>,
  );
}

/// Handles PUT requests: Updates an existing source by its ID.
///
/// The request body must be a valid JSON representation of a source.
Future<Response> _handlePut(RequestContext context, String id) async {
  final requestBody = await context.request.json() as Map<String, dynamic>?;
  if (requestBody == null) {
    throw const BadRequestException('Missing or invalid request body.');
  }

  requestBody['updatedAt'] = DateTime.now().toUtc().toIso8601String();

  Source itemToUpdate;
  try {
    itemToUpdate = Source.fromJson(requestBody);
  } on TypeError catch (e, s) {
    _logger.warning('Deserialization TypeError in PUT /sources/[id]', e, s);
    throw const BadRequestException(
      'Invalid request body: Missing or invalid required field(s).',
    );
  }

  if (itemToUpdate.id != id) {
    throw BadRequestException(
      'Bad Request: ID in request body ("${itemToUpdate.id}") does not match ID in path ("$id").',
    );
  }

  final repo = context.read<DataRepository<Source>>();
  final updatedItem = await repo.update(
    id: id,
    item: itemToUpdate,
  );

  return ResponseHelper.success(
    context: context,
    data: updatedItem,
    toJsonT: (data) => (data as dynamic).toJson() as Map<String, dynamic>,
  );
}

/// Handles DELETE requests: Deletes a source by its ID.
Future<Response> _handleDelete(RequestContext context, String id) async {
  final repo = context.read<DataRepository<Source>>();
  await repo.delete(id: id);

  return Response(statusCode: HttpStatus.noContent);
}
