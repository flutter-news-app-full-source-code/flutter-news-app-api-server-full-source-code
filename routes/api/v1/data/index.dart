import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/helpers/response_helper.dart';
import 'package:ht_api/src/rbac/permission_service.dart';
import 'package:ht_api/src/registry/model_registry.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_shared/ht_shared.dart';

/// Handles requests for the /api/v1/data collection endpoint.
/// Dispatches requests to specific handlers based on the HTTP method.
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

/// Handles GET requests: Retrieves a collection of items.
///
/// This handler now accepts a single, JSON-encoded `filter` parameter for
/// MongoDB-style queries, along with `sort` and pagination parameters.
Future<Response> _handleGet(RequestContext context) async {
  // Read dependencies provided by middleware
  final modelName = context.read<String>();
  final modelConfig = context.read<ModelConfig<dynamic>>();
  final authenticatedUser = context.read<User>();

  // --- Parse Query Parameters ---
  final params = context.request.uri.queryParameters;

  // 1. Parse Filter (MongoDB-style)
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

  // 2. Parse Sort
  List<SortOption>? sort;
  if (params.containsKey('sort')) {
    try {
      sort = params['sort']!
          .split(',')
          .map((s) {
            final parts = s.split(':');
            final field = parts[0];
            final order = (parts.length > 1 && parts[1] == 'desc')
                ? SortOrder.desc
                : SortOrder.asc;
            return SortOption(field, order);
          })
          .toList();
    } catch (e) {
      throw const BadRequestException(
        'Invalid "sort" parameter format. Use "field:order,field2:order".',
      );
    }
  }

  // 3. Parse Pagination
  PaginationOptions? pagination;
  if (params.containsKey('limit') || params.containsKey('cursor')) {
    final limit = int.tryParse(params['limit'] ?? '');
    pagination = PaginationOptions(cursor: params['cursor'], limit: limit);
  }

  // --- Repository Call ---
  final userIdForRepoCall = (modelConfig.getOwnerId != null &&
          !context.read<PermissionService>().isAdmin(authenticatedUser))
      ? authenticatedUser.id
      : null;

  dynamic responseData;

  // The switch statement now only dispatches to the correct repository type.
  // The query logic is handled by the repository/client.
  switch (modelName) {
    case 'headline':
      final repo = context.read<HtDataRepository<Headline>>();
      responseData = await repo.readAll(
        userId: userIdForRepoCall,
        filter: filter,
        sort: sort,
        pagination: pagination,
      );
    case 'topic':
      final repo = context.read<HtDataRepository<Topic>>();
      responseData = await repo.readAll(
        userId: userIdForRepoCall,
        filter: filter,
        sort: sort,
        pagination: pagination,
      );
    case 'source':
      final repo = context.read<HtDataRepository<Source>>();
      responseData = await repo.readAll(
        userId: userIdForRepoCall,
        filter: filter,
        sort: sort,
        pagination: pagination,
      );
    case 'country':
      final repo = context.read<HtDataRepository<Country>>();
      responseData = await repo.readAll(
        userId: userIdForRepoCall,
        filter: filter,
        sort: sort,
        pagination: pagination,
      );
    case 'user':
      final repo = context.read<HtDataRepository<User>>();
      responseData = await repo.readAll(
        userId: userIdForRepoCall,
        filter: filter,
        sort: sort,
        pagination: pagination,
      );
    default:
      throw OperationFailedException(
        'Unsupported model type "$modelName" for GET all.',
      );
  }

  return ResponseHelper.success(
    context: context,
    data: responseData,
    toJsonT: (paginated) => (paginated as PaginatedResponse<dynamic>)
        .toJson((item) => (item as dynamic).toJson()),
  );
}

/// Handles POST requests: Creates a new item in a collection.
Future<Response> _handlePost(RequestContext context) async {
  // Read dependencies from middleware
  final modelName = context.read<String>();
  final modelConfig = context.read<ModelConfig<dynamic>>();
  final authenticatedUser = context.read<User>();

  // --- Parse Body ---
  final requestBody = await context.request.json() as Map<String, dynamic>?;
  if (requestBody == null) {
    throw const BadRequestException('Missing or invalid request body.');
  }

  dynamic itemToCreate;
  try {
    itemToCreate = modelConfig.fromJson(requestBody);
  } on TypeError catch (e) {
    throw BadRequestException(
      'Invalid request body: Missing or invalid required field(s). $e',
    );
  }

  // --- Repository Call ---
  final userIdForRepoCall = (modelConfig.getOwnerId != null &&
          !context.read<PermissionService>().isAdmin(authenticatedUser))
      ? authenticatedUser.id
      : null;

  dynamic createdItem;
  switch (modelName) {
    case 'headline':
      final repo = context.read<HtDataRepository<Headline>>();
      createdItem = await repo.create(
        item: itemToCreate as Headline,
        userId: userIdForRepoCall,
      );
    case 'topic':
      final repo = context.read<HtDataRepository<Topic>>();
      createdItem = await repo.create(
        item: itemToCreate as Topic,
        userId: userIdForRepoCall,
      );
    case 'source':
      final repo = context.read<HtDataRepository<Source>>();
      createdItem = await repo.create(
        item: itemToCreate as Source,
        userId: userIdForRepoCall,
      );
    case 'country':
      final repo = context.read<HtDataRepository<Country>>();
      createdItem = await repo.create(
        item: itemToCreate as Country,
        userId: userIdForRepoCall,
      );
    case 'remote_config':
      final repo = context.read<HtDataRepository<RemoteConfig>>();
      createdItem = await repo.create(
        item: itemToCreate as RemoteConfig,
        userId: userIdForRepoCall,
      );
    default:
      throw OperationFailedException(
        'Unsupported model type "$modelName" for POST.',
      );
  }

  return ResponseHelper.success(
    context: context,
    data: createdItem,
    toJsonT: (item) => (item as dynamic).toJson(),
    statusCode: HttpStatus.created,
  );
}