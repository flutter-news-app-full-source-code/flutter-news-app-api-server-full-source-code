import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/response_helper.dart';

/// Handles requests for the /api/v1/users collection endpoint.
///
/// This endpoint supports GET for retrieving a list of users.
Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _handleGet(context);
    default:
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

/// Handles GET requests: Retrieves a collection of users.
///
/// Supports filtering, sorting, and pagination.
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

  final repo = context.read<DataRepository<User>>();
  final responseData = await repo.readAll(
    filter: filter,
    sort: sort,
    pagination: pagination,
  );

  return ResponseHelper.success(
    context: context,
    data: responseData,
    toJsonT: (paginated) => (paginated as PaginatedResponse<dynamic>).toJson(
      (item) => (item as dynamic).toJson() as Map<String, dynamic>,
    ),
  );
}
