import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/response_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Handles requests for the /api/v1/remote-configs collection endpoint.
Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _handleGet(context);
    case HttpMethod.post:
      return _handlePost(context);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

/// Handles GET requests: Retrieves a collection of remote configs.
Future<Response> _handleGet(RequestContext context) async {
  final params = context.request.uri.queryParameters;

  Map<String, dynamic>? filter;
  if (params.containsKey('filter')) {
    try {
      filter = jsonDecode(params['filter']!) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw BadRequestException(
        'Invalid "filter" parameter: Not valid JSON. $e',
      );
    }
  }

  List<SortOption>? sort;
  if (params.containsKey('sort')) {
    try {
      sort = params['sort']!.split(',').map((s) {
        final parts = s.split(':');
        final field = parts[0];
        final order = (parts.length > 1 && parts[1] == 'desc')
            ? SortOrder.desc
            : SortOrder.asc;
        return SortOption(field, order);
      }).toList();
    } catch (e) {
      throw const BadRequestException(
        'Invalid "sort" parameter format. Use "field:order,field2:order".',
      );
    }
  }

  PaginationOptions? pagination;
  if (params.containsKey('limit') || params.containsKey('cursor')) {
    final limit = int.tryParse(params['limit'] ?? '');
    pagination = PaginationOptions(cursor: params['cursor'], limit: limit);
  }

  final repo = context.read<DataRepository<RemoteConfig>>();
  final responseData = await repo.readAll(
    filter: filter,
    sort: sort,
    pagination: pagination,
  );

  return ResponseHelper.success(
    context: context,
    data: responseData,
    toJsonT: (paginated) =>
        paginated.toJson(
      (item) => item.toJson(),
    ),
  );
}

/// Handles POST requests: Creates a new remote config.
Future<Response> _handlePost(RequestContext context) async {
  final requestBody = await context.request.json() as Map<String, dynamic>?;
  if (requestBody == null) {
    throw const BadRequestException('Missing or invalid request body.');
  }

  final now = DateTime.now().toUtc();
  requestBody['id'] = ObjectId().oid;
  requestBody['createdAt'] = now.toIso8601String();
  requestBody['updatedAt'] = now.toIso8601String();

  final itemToCreate = RemoteConfig.fromJson(requestBody);

  final repo = context.read<DataRepository<RemoteConfig>>();
  final createdItem = await repo.create(item: itemToCreate);

  return ResponseHelper.success(
    context: context,
    data: createdItem,
    toJsonT: (item) => item.toJson(),
    statusCode: HttpStatus.created,
  );
}
