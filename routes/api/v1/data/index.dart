import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/response_helper.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Handles requests for the /api/v1/data collection endpoint.
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
Future<Response> _handleGet(RequestContext context) async {
  final modelName = context.read<String>();
  final modelConfig = context.read<ModelConfig<dynamic>>();
  final authenticatedUser = context.read<User>();
  final params = context.request.uri.queryParameters;

  final filter = params.containsKey('filter')
      ? jsonDecode(params['filter']!) as Map<String, dynamic>
      : null;

  final sort = params.containsKey('sort')
      ? (params['sort']!.split(',').map((s) {
          final parts = s.split(':');
          final field = parts[0];
          final order = (parts.length > 1 && parts[1] == 'desc')
              ? SortOrder.desc
              : SortOrder.asc;
          return SortOption(field, order);
        }).toList())
      : null;

  final pagination =
      (params.containsKey('limit') || params.containsKey('cursor'))
      ? PaginationOptions(
          cursor: params['cursor'],
          limit: int.tryParse(params['limit'] ?? ''),
        )
      : null;

  final userIdForRepoCall =
      (modelConfig.getOwnerId != null &&
          !context.read<PermissionService>().isAdmin(authenticatedUser))
      ? authenticatedUser.id
      : null;

  final responseData = await _readAllItems(
    context,
    modelName,
    userIdForRepoCall,
    filter,
    sort,
    pagination,
  );

  return ResponseHelper.success(
    context: context,
    data: responseData,
    toJsonT: (paginated) => paginated.toJson(
      (item) => (item as dynamic).toJson() as Map<String, dynamic>,
    ),
  );
}

/// Handles POST requests: Creates a new item in a collection.
Future<Response> _handlePost(RequestContext context) async {
  final modelName = context.read<String>();
  final modelConfig = context.read<ModelConfig<dynamic>>();
  final authenticatedUser = context.read<User>();

  final requestBody = await context.request.json() as Map<String, dynamic>?;
  if (requestBody == null) {
    throw const BadRequestException('Missing or invalid request body.');
  }

  final now = DateTime.now().toUtc().toIso8601String();
  requestBody['id'] = ObjectId().oid;
  requestBody['createdAt'] = now;
  requestBody['updatedAt'] = now;

  final itemToCreate = modelConfig.fromJson(requestBody);

  final userIdForRepoCall =
      (modelConfig.getOwnerId != null &&
          !context.read<PermissionService>().isAdmin(authenticatedUser))
      ? authenticatedUser.id
      : null;

  final createdItem = await _createItem(
    context,
    modelName,
    itemToCreate,
    userIdForRepoCall,
  );

  return ResponseHelper.success(
    context: context,
    data: createdItem,
    toJsonT: (item) => (item as dynamic).toJson() as Map<String, dynamic>,
    statusCode: HttpStatus.created,
  );
}

// =============================================================================
// --- Helper Functions ---
// =============================================================================

/// Encapsulates the logic for reading a collection of items by type.
Future<PaginatedResponse<dynamic>> _readAllItems(
  RequestContext context,
  String modelName,
  String? userId,
  Map<String, dynamic>? filter,
  List<SortOption>? sort,
  PaginationOptions? pagination,
) {
  switch (modelName) {
    case 'headline':
      return context.read<DataRepository<Headline>>().readAll(
        userId: userId,
        filter: filter,
        sort: sort,
        pagination: pagination,
      );
    case 'topic':
      return context.read<DataRepository<Topic>>().readAll(
        userId: userId,
        filter: filter,
        sort: sort,
        pagination: pagination,
      );
    case 'source':
      return context.read<DataRepository<Source>>().readAll(
        userId: userId,
        filter: filter,
        sort: sort,
        pagination: pagination,
      );
    case 'country':
      return context.read<DataRepository<Country>>().readAll(
        userId: userId,
        filter: filter,
        sort: sort,
        pagination: pagination,
      );
    case 'language':
      return context.read<DataRepository<Language>>().readAll(
        userId: userId,
        filter: filter,
        sort: sort,
        pagination: pagination,
      );
    case 'user':
      return context.read<DataRepository<User>>().readAll(
        userId: userId,
        filter: filter,
        sort: sort,
        pagination: pagination,
      );
    default:
      throw OperationFailedException(
        'Unsupported model type "$modelName" for GET all.',
      );
  }
}

/// Encapsulates the logic for creating an item by its type.
Future<dynamic> _createItem(
  RequestContext context,
  String modelName,
  dynamic itemToCreate,
  String? userId,
) {
  switch (modelName) {
    case 'headline':
      return context.read<DataRepository<Headline>>().create(
        item: itemToCreate as Headline,
        userId: userId,
      );
    case 'topic':
      return context.read<DataRepository<Topic>>().create(
        item: itemToCreate as Topic,
        userId: userId,
      );
    case 'source':
      return context.read<DataRepository<Source>>().create(
        item: itemToCreate as Source,
        userId: userId,
      );
    case 'country':
      return context.read<DataRepository<Country>>().create(
        item: itemToCreate as Country,
        userId: userId,
      );
    case 'language':
      return context.read<DataRepository<Language>>().create(
        item: itemToCreate as Language,
        userId: userId,
      );
    case 'remote_config':
      return context.read<DataRepository<RemoteConfig>>().create(
        item: itemToCreate as RemoteConfig,
        userId: userId,
      );
    default:
      throw OperationFailedException(
        'Unsupported model type "$modelName" for POST.',
      );
  }
}
