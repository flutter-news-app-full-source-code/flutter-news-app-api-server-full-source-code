import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/response_helper.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/dashboard_summary_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/user_preference_limit_service.dart';
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
Future<Response> _handleGet(RequestContext context, String id) async {
  final modelName = context.read<String>();
  final modelConfig = context.read<ModelConfig<dynamic>>();
  final authenticatedUser = context.read<User>();
  final permissionService = context.read<PermissionService>();

  _logger.info(
    'Handling GET request for model "$modelName", id "$id".',
  );

  dynamic item;
  final fetchedItem = context.read<FetchedItem<dynamic>?>();

  if (fetchedItem != null) {
    _logger.finer('Item was pre-fetched by middleware.');
    item = fetchedItem.data;
  } else {
    _logger.finer('Item not pre-fetched, calling _readItem helper.');
    final userIdForRepoCall = _getUserIdForRepoCall(
      modelConfig: modelConfig,
      permissionService: permissionService,
      authenticatedUser: authenticatedUser,
    );
    item = await _readItem(context, modelName, id, userIdForRepoCall);
  }

  _logger.finer('Item fetch completed. Result: ${item == null ? "null" : "found"}.');

  // This check is now crucial for preventing the NoSuchMethodError on null.
  if (item == null) {
    throw NotFoundException('Item with id "$id" not found.');
  }

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
  final authenticatedUser = context.read<User>();
  final permissionService = context.read<PermissionService>();
  final userPreferenceLimitService =
      context.read<UserPreferenceLimitService>();

  _logger.info(
    'Handling PUT request for model "$modelName", id "$id".',
  );

  final requestBody = await context.request.json() as Map<String, dynamic>?;
  if (requestBody == null) {
    throw const BadRequestException('Missing or invalid request body.');
  }

  requestBody['updatedAt'] = DateTime.now().toUtc().toIso8601String();

  dynamic itemToUpdate;
  try {
    itemToUpdate = modelConfig.fromJson(requestBody);
  } on TypeError catch (e, s) {
    _logger.warning('Deserialization TypeError in PUT /data/[id]', e, s);
    throw const BadRequestException(
      'Invalid request body: Missing or invalid required field(s).',
    );
  }

  try {
    final bodyItemId = modelConfig.getId(itemToUpdate);
    if (bodyItemId != id) {
      throw BadRequestException(
        'Bad Request: ID in request body ("$bodyItemId") does not match ID in path ("$id").',
      );
    }
  } catch (e) {
    // Ignore if getId throws, as the ID might not be in the body,
    // which can be acceptable for some models.
    _logger.info('Could not get ID from PUT body: $e');
  }

  if (modelName == 'user_content_preferences') {
    if (itemToUpdate is UserContentPreferences) {
      await userPreferenceLimitService.checkUpdatePreferences(
        authenticatedUser,
        itemToUpdate,
      );
    } else {
      _logger.severe(
        'Type Error: Expected UserContentPreferences for limit check, but got ${itemToUpdate.runtimeType}.',
      );
      throw const OperationFailedException(
        'Internal Server Error: Model type mismatch for limit check.',
      );
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
  final authenticatedUser = context.read<User>();
  final permissionService = context.read<PermissionService>();

  _logger.info(
    'Handling DELETE request for model "$modelName", id "$id".',
  );

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
String? _getUserIdForRepoCall({
  required ModelConfig<dynamic> modelConfig,
  required PermissionService permissionService,
  required User authenticatedUser,
}) {
  return (modelConfig.getOwnerId != null &&
          !permissionService.isAdmin(authenticatedUser))
      ? authenticatedUser.id
      : null;
}

/// Encapsulates the logic for reading a single item by its type.
Future<dynamic> _readItem(
  RequestContext context,
  String modelName,
  String id,
  String? userId,
) async {
  _logger.finer(
    'Executing _readItem for model "$modelName", id "$id", userId: $userId.',
  );
  try {
    switch (modelName) {
      case 'headline':
        return await context.read<DataRepository<Headline>>().read(
              id: id,
              userId: userId,
            );
      case 'topic':
        return await context
            .read<DataRepository<Topic>>()
            .read(id: id, userId: userId);
      case 'source':
        return await context.read<DataRepository<Source>>().read(
              id: id,
              userId: userId,
            );
      case 'country':
        return await context.read<DataRepository<Country>>().read(
              id: id,
              userId: userId,
            );
      case 'language':
        return await context.read<DataRepository<Language>>().read(
              id: id,
              userId: userId,
            );
      case 'user':
        return await context
            .read<DataRepository<User>>()
            .read(id: id, userId: userId);
      case 'user_app_settings':
        return await context.read<DataRepository<UserAppSettings>>().read(
              id: id,
              userId: userId,
            );
      case 'user_content_preferences':
        return await context.read<DataRepository<UserContentPreferences>>().read(
              id: id,
              userId: userId,
            );
      case 'remote_config':
        return await context.read<DataRepository<RemoteConfig>>().read(
              id: id,
              userId: userId,
            );
      case 'dashboard_summary':
        return await context.read<DashboardSummaryService>().getSummary();
      default:
        _logger.warning('Unsupported model type "$modelName" for read operation.');
        throw OperationFailedException(
          'Unsupported model type "$modelName" for read operation.',
        );
    }
  } catch (e, s) {
    _logger.severe(
      'Unhandled exception in _readItem for model "$modelName", id "$id".',
      e,
      s,
    );
    // Re-throw as a standard exception type that the main error handler
    // can process into a 500 error, while preserving the original cause.
    throw OperationFailedException(
      'An internal error occurred while reading the item: $e',
    );
  }
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
    switch (modelName) {
      case 'headline':
        return await context.read<DataRepository<Headline>>().update(
              id: id,
              item: itemToUpdate as Headline,
              userId: userId,
            );
      case 'topic':
        return await context.read<DataRepository<Topic>>().update(
              id: id,
              item: itemToUpdate as Topic,
              userId: userId,
            );
      case 'source':
        return await context.read<DataRepository<Source>>().update(
              id: id,
              item: itemToUpdate as Source,
              userId: userId,
            );
      case 'country':
        return await context.read<DataRepository<Country>>().update(
              id: id,
              item: itemToUpdate as Country,
              userId: userId,
            );
      case 'language':
        return await context.read<DataRepository<Language>>().update(
              id: id,
              item: itemToUpdate as Language,
              userId: userId,
            );
      case 'user':
        final repo = context.read<DataRepository<User>>();
        final existingUser = context.read<FetchedItem<dynamic>>().data as User;
        final updatedUser = existingUser.copyWith(
          feedActionStatus: (itemToUpdate as User).feedActionStatus,
        );
        return await repo.update(id: id, item: updatedUser, userId: userId);
      case 'user_app_settings':
        return await context.read<DataRepository<UserAppSettings>>().update(
              id: id,
              item: itemToUpdate as UserAppSettings,
              userId: userId,
            );
      case 'user_content_preferences':
        return await context
            .read<DataRepository<UserContentPreferences>>()
            .update(
              id: id,
              item: itemToUpdate as UserContentPreferences,
              userId: userId,
            );
      case 'remote_config':
        return await context.read<DataRepository<RemoteConfig>>().update(
              id: id,
              item: itemToUpdate as RemoteConfig,
              userId: userId,
            );
      default:
        _logger.warning('Unsupported model type "$modelName" for update operation.');
        throw OperationFailedException(
          'Unsupported model type "$modelName" for update operation.',
        );
    }
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
    switch (modelName) {
      case 'headline':
        return await context.read<DataRepository<Headline>>().delete(
              id: id,
              userId: userId,
            );
      case 'topic':
        return await context.read<DataRepository<Topic>>().delete(
              id: id,
              userId: userId,
            );
      case 'source':
        return await context.read<DataRepository<Source>>().delete(
              id: id,
              userId: userId,
            );
      case 'country':
        return await context.read<DataRepository<Country>>().delete(
              id: id,
              userId: userId,
            );
      case 'language':
        return await context.read<DataRepository<Language>>().delete(
              id: id,
              userId: userId,
            );
      case 'user':
        return await context.read<DataRepository<User>>().delete(
              id: id,
              userId: userId,
            );
      case 'user_app_settings':
        return await context.read<DataRepository<UserAppSettings>>().delete(
              id: id,
              userId: userId,
            );
      case 'user_content_preferences':
        return await context.read<DataRepository<UserContentPreferences>>().delete(
              id: id,
              userId: userId,
            );
      case 'remote_config':
        return await context.read<DataRepository<RemoteConfig>>().delete(
              id: id,
              userId: userId,
            );
      default:
        _logger.warning('Unsupported model type "$modelName" for delete operation.');
        throw OperationFailedException(
          'Unsupported model type "$modelName" for delete operation.',
        );
    }
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
