import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/helpers/response_helper.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/registry/data_operation_registry.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/registry/model_registry.dart';
import 'package:logging/logging.dart';

// Create a logger for this file.
final _logger = Logger('data_item_handler');

/// Handles requests for the /api/v1/data/[id] endpoint.
/// Dispatches requests to specific handlers based on the HTTP method.
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

// --- GET Handler ---
/// Handles GET requests: Retrieves a single item by its ID.
///
/// This handler can safely assume that the requested item has already been
/// fetched, validated, and provided in the context by the upstream
/// `dataFetchMiddleware`. Its primary role is to construct the success
/// response.
Future<Response> _handleGet(RequestContext context, String id) async {
  final modelName = context.read<String>();
  _logger.info('Handling GET request for model "$modelName", id "$id".');

  // The item is guaranteed to be present by the dataFetchMiddleware.
  final item = context.read<FetchedItem<dynamic>>().data;
  _logger.finer('Item was pre-fetched by middleware. Preparing response.');

  return ResponseHelper.success(
    context: context,
    data: item,
    toJsonT: (data) => (data as dynamic).toJson() as Map<String, dynamic>,
  );
}

// --- PUT Handler ---
/// Handles PUT requests: Updates an existing item by its ID.
Future<Response> _handlePut(RequestContext context, String id) async {
  final modelName = context.read<String>();
  final modelConfig = context.read<ModelConfig<dynamic>>();
  final authenticatedUser = context.read<User?>();
  final permissionService = context.read<PermissionService>();

  _logger.info('Handling PUT request for model "$modelName", id "$id".');

  Map<String, dynamic>? requestBody;
  try {
    requestBody = await context.request.json() as Map<String, dynamic>?;
  } on FormatException {
    throw const BadRequestException('Invalid JSON in request body.');
  }

  if (requestBody == null) {
    throw const BadRequestException('Missing or invalid request body.');
  }

  requestBody['updatedAt'] = DateTime.now().toUtc().toIso8601String();

  // The item to be passed to the updater function.
  // For 'user' updates, this will be the raw request body map to allow for
  // secure, selective field merging in the DataOperationRegistry.
  // For all other models, it's the deserialized object.
  dynamic itemToUpdate;

  if (modelName == 'user') {
    // For user updates, we pass the raw map to the updater.
    // This allows the updater to selectively apply fields, preventing mass
    // assignment vulnerabilities. The ID check is also skipped as the request
    // body for a user role update will not contain an ID.
    _logger.finer('User model update: using raw request body for updater.');
    itemToUpdate = requestBody;
  } else {
    // For all other models, deserialize the body into a model instance.
    try {
      itemToUpdate = modelConfig.fromJson(requestBody);
    } catch (e, s) {
      _logger.warning('Deserialization Error in PUT /data/[id]', e, s);
      throw const BadRequestException(
        'Invalid request body: Missing or invalid required field(s).',
      );
    }

    // Validate that the ID in the body matches the ID in the path.
    try {
      final bodyItemId = modelConfig.getId(itemToUpdate);
      if (bodyItemId != id) {
        throw BadRequestException(
          'Bad Request: ID in request body ("$bodyItemId") does not match ID in path ("$id").',
        );
      }
    } catch (e) {
      _logger.info('Could not get ID from PUT body: $e');
    }
  }

  final userIdForRepoCall = _getUserIdForRepoCall(
    modelConfig: modelConfig,
    permissionService: permissionService,
    authenticatedUser: authenticatedUser,
  );

  final updatedItem = await _updateItem(
    context,
    modelName,
    id,
    itemToUpdate,
    userIdForRepoCall,
  );

  return ResponseHelper.success(
    context: context,
    data: updatedItem,
    toJsonT: (data) => (data as dynamic).toJson() as Map<String, dynamic>,
  );
}

// --- DELETE Handler ---
/// Handles DELETE requests: Deletes an item by its ID.
Future<Response> _handleDelete(RequestContext context, String id) async {
  final modelName = context.read<String>();
  final modelConfig = context.read<ModelConfig<dynamic>>();
  final authenticatedUser = context.read<User?>();
  final permissionService = context.read<PermissionService>();

  _logger.info('Handling DELETE request for model "$modelName", id "$id".');

  final userIdForRepoCall = _getUserIdForRepoCall(
    modelConfig: modelConfig,
    permissionService: permissionService,
    authenticatedUser: authenticatedUser,
  );

  await _deleteItem(context, modelName, id, userIdForRepoCall);

  return Response(statusCode: HttpStatus.noContent);
}

// =============================================================================
// --- Helper Functions ---
// =============================================================================

/// Determines the `userId` to be used for a repository call based on user
/// role and model configuration.
///
/// If the model is user-owned and the authenticated user is not an admin,
/// the authenticated user's ID is returned. Otherwise, `null` is returned,
/// indicating a global operation or an admin-level bypass.
String? _getUserIdForRepoCall({
  required ModelConfig<dynamic> modelConfig,
  required PermissionService permissionService,
  required User? authenticatedUser,
}) {
  // If the model is user-owned and the user is authenticated and not an admin,
  // then the operation should be scoped to the authenticated user's ID.
  // Otherwise, it's a global operation or an admin bypass.
  return (modelConfig.getOwnerId != null &&
          authenticatedUser != null &&
          !permissionService.isAdmin(authenticatedUser))
      ? authenticatedUser.id
      : null;
}

/// Encapsulates the logic for updating an item by its type.
Future<dynamic> _updateItem(
  RequestContext context,
  String modelName,
  String id,
  dynamic itemToUpdate,
  String? userId,
) async {
  _logger.finer(
    'Executing _updateItem for model "$modelName", id "$id", userId: $userId.',
  );
  try {
    final registry = context.read<DataOperationRegistry>();
    final updater = registry.itemUpdaters[modelName];

    if (updater == null) {
      _logger.warning(
        'Unsupported model type "$modelName" for update operation.',
      );
      throw OperationFailedException(
        'Unsupported model type "$modelName" for update operation.',
      );
    }
    return await updater(context, id, itemToUpdate, userId);
  } catch (e, s) {
    _logger.severe(
      'Unhandled exception in _updateItem for model "$modelName", id "$id".',
      e,
      s,
    );
    throw OperationFailedException(
      'An internal error occurred while updating the item: $e',
    );
  }
}

/// Encapsulates the logic for deleting an item by its type.
Future<void> _deleteItem(
  RequestContext context,
  String modelName,
  String id,
  String? userId,
) async {
  _logger.finer(
    'Executing _deleteItem for model "$modelName", id "$id", userId: $userId.',
  );
  try {
    final registry = context.read<DataOperationRegistry>();
    final deleter = registry.itemDeleters[modelName];

    if (deleter == null) {
      _logger.warning(
        'Unsupported model type "$modelName" for delete operation.',
      );
      throw OperationFailedException(
        'Unsupported model type "$modelName" for delete operation.',
      );
    }
    return await deleter(context, id, userId);
  } catch (e, s) {
    _logger.severe(
      'Unhandled exception in _deleteItem for model "$modelName", id "$id".',
      e,
      s,
    );
    throw OperationFailedException(
      'An internal error occurred while deleting the item: $e',
    );
  }
}
