import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/response_helper.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/data_operation_registry.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

// Create a logger for this file.
final _logger = Logger('data_collection_handler');

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
  // Read authenticatedUser as nullable, as per configurable authentication.
  final authenticatedUser = context.read<User?>();
  final params = context.request.uri.queryParameters;

  _logger
    ..info('Handling GET collection request for model "$modelName".')
    ..finer('Query parameters: $params');

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

  final pagination =
      (params.containsKey('limit') || params.containsKey('cursor'))
      ? PaginationOptions(
          cursor: params['cursor'],
          limit: int.tryParse(params['limit'] ?? ''),
        )
      : null;

  // Determine userId for repository call.
  // If the model is user-owned and the user is authenticated and not an admin,
  // then the operation should be scoped to the authenticated user's ID.
  // Otherwise, it's a global operation or an admin bypass.
  final userIdForRepoCall =
      (modelConfig.getOwnerId != null &&
          authenticatedUser != null &&
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
  // Read authenticatedUser as nullable, as per configurable authentication.
  final authenticatedUser = context.read<User?>();

  _logger.info('Handling POST request for model "$modelName".');

  Map<String, dynamic>? requestBody;
  try {
    requestBody = await context.request.json() as Map<String, dynamic>?;
  } on FormatException {
    throw const BadRequestException('Invalid JSON in request body.');
  }

  if (requestBody == null) {
    throw const BadRequestException('Missing or invalid request body.');
  }

  // For user creation, ensure the email field is present.
  if (modelName == 'user') {
    if (!requestBody.containsKey('email') ||
        (requestBody['email'] as String).isEmpty) {
      throw const BadRequestException('Missing required field: "email".');
    }
  }

  final now = DateTime.now().toUtc().toIso8601String();
  requestBody['id'] = ObjectId().oid;
  requestBody['createdAt'] = now;
  requestBody['updatedAt'] = now;

  dynamic itemToCreate;
  try {
    itemToCreate = modelConfig.fromJson(requestBody);
  } catch (e) {
    throw BadRequestException(
      'Invalid request body: Missing or invalid required field(s). $e',
    );
  }

  // Determine userId for repository call.
  // If the model is user-owned and the user is authenticated and not an admin,
  // then the operation should be scoped to the authenticated user's ID.
  // Otherwise, it's a global operation or an admin bypass.
  final userIdForRepoCall =
      (modelConfig.getOwnerId != null &&
          authenticatedUser != null &&
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
) async {
  _logger.finer(
    'Executing _readAllItems for model "$modelName", userId: $userId.',
  );
  try {
    final registry = context.read<DataOperationRegistry>();
    final reader = registry.allItemsReaders[modelName];

    if (reader == null) {
      _logger.warning('Unsupported model type "$modelName" for GET all.');
      throw OperationFailedException(
        'Unsupported model type "$modelName" for GET all.',
      );
    }
    return await reader(context, userId, filter, sort, pagination);
  } catch (e, s) {
    _logger.severe(
      'Unhandled exception in _readAllItems for model "$modelName".',
      e,
      s,
    );
    throw OperationFailedException(
      'An internal error occurred while reading the collection: $e',
    );
  }
}

/// Encapsulates the logic for creating an item by its type.
Future<dynamic> _createItem(
  RequestContext context,
  String modelName,
  dynamic itemToCreate,
  String? userId,
) async {
  _logger.finer(
    'Executing _createItem for model "$modelName", userId: $userId.',
  );
  try {
    final registry = context.read<DataOperationRegistry>();
    final creator = registry.itemCreators[modelName];

    if (creator == null) {
      _logger.warning('Unsupported model type "$modelName" for POST.');
      throw OperationFailedException(
        'Unsupported model type "$modelName" for POST.',
      );
    }
    return await creator(context, itemToCreate, userId);
  } catch (e, s) {
    _logger.severe(
      'Unhandled exception in _createItem for model "$modelName".',
      e,
      s,
    );
    throw OperationFailedException(
      'An internal error occurred while creating the item: $e',
    );
  }
}
