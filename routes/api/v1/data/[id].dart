import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/rbac/permission_service.dart';
import 'package:ht_api/src/registry/model_registry.dart';
import 'package:ht_api/src/services/user_preference_limit_service.dart'; // Import UserPreferenceLimitService
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_shared/ht_shared.dart';

import '../../../_middleware.dart'; // Assuming RequestId is here

/// Handles requests for the /api/v1/data/[id] endpoint.
/// Dispatches requests to specific handlers based on the HTTP method.
Future<Response> onRequest(RequestContext context, String id) async {
  // Read dependencies provided by middleware
  final modelName = context.read<String>();
  final modelConfig = context.read<ModelConfig<dynamic>>();
  final requestId = context.read<RequestId>().id;
  // User is guaranteed non-null by requireAuthentication() middleware
  final authenticatedUser = context.read<User>();
  final permissionService =
      context.read<PermissionService>(); // Read PermissionService
  // Read the UserPreferenceLimitService (only needed for UserContentPreferences PUT)
  final userPreferenceLimitService = context.read<UserPreferenceLimitService>();

  // The main try/catch block here is removed to let the errorHandler middleware
  // handle all exceptions thrown by the handlers below.
  switch (context.request.method) {
    case HttpMethod.get:
      return _handleGet(
        context,
        id,
        modelName,
        modelConfig,
        authenticatedUser,
        permissionService, // Pass PermissionService
        requestId,
      );
    case HttpMethod.put:
      return _handlePut(
        context,
        id,
        modelName,
        modelConfig,
        authenticatedUser,
        permissionService, // Pass PermissionService
        userPreferenceLimitService, // Pass the limit service
        requestId,
      );
    case HttpMethod.delete:
      return _handleDelete(
        context,
        id,
        modelName,
        modelConfig,
        authenticatedUser,
        permissionService, // Pass PermissionService
        requestId,
      );
    default:
      // Methods not allowed on the item endpoint
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

// --- GET Handler ---
/// Handles GET requests: Retrieves a single item by its ID.
/// Includes request metadata in response.
Future<Response> _handleGet(
  RequestContext context,
  String id,
  String modelName,
  ModelConfig<dynamic> modelConfig,
  User authenticatedUser,
  PermissionService permissionService,
  String requestId,
) async {
  // Authorization check is handled by authorizationMiddleware before this.
  // This handler only needs to perform the ownership check if required.

  dynamic item;

  // Determine userId for repository call based on ModelConfig (for data scoping)
  String? userIdForRepoCall;
  // If the model is user-owned, pass the authenticated user's ID to the repository
  // for filtering. Otherwise, pass null.
  // Note: This is for data *scoping* by the repository, not the permission check.
  // We infer user-owned based on the presence of getOwnerId function.
  if (modelConfig.getOwnerId != null) {
    userIdForRepoCall = authenticatedUser.id;
  } else {
    userIdForRepoCall = null;
  }

  // Repository exceptions (like NotFoundException) will propagate up to the
  // main onRequest try/catch (which is now removed, so they go to errorHandler).
  switch (modelName) {
    case 'headline':
      final repo = context.read<HtDataRepository<Headline>>();
      item = await repo.read(id: id, userId: userIdForRepoCall);
    case 'category':
      final repo = context.read<HtDataRepository<Category>>();
      item = await repo.read(id: id, userId: userIdForRepoCall);
    case 'source':
      final repo = context.read<HtDataRepository<Source>>();
      item = await repo.read(id: id, userId: userIdForRepoCall);
    case 'country':
      final repo = context.read<HtDataRepository<Country>>();
      item = await repo.read(id: id, userId: userIdForRepoCall);
    case 'user': // Handle User model specifically if needed, or rely on generic
      final repo = context.read<HtDataRepository<User>>();
      item = await repo.read(id: id, userId: userIdForRepoCall);
    case 'user_app_settings': // New case for UserAppSettings
      final repo = context.read<HtDataRepository<UserAppSettings>>();
      item = await repo.read(id: id, userId: userIdForRepoCall);
    case 'user_content_preferences': // New case for UserContentPreferences
      final repo = context.read<HtDataRepository<UserContentPreferences>>();
      item = await repo.read(id: id, userId: userIdForRepoCall);
    case 'app_config': // New case for AppConfig (read by admin)
      final repo = context.read<HtDataRepository<AppConfig>>();
      item = await repo.read(
        id: id,
        userId: userIdForRepoCall,
      ); // userId should be null for AppConfig
    default:
      // This case should ideally be caught by middleware, but added for safety
      // Throw an exception to be caught by the errorHandler
      throw OperationFailedException(
        'Unsupported model type "$modelName" reached handler.',
      );
  }

  // --- Handler-Level Ownership Check (for GET item) ---
  // This check is needed if the ModelConfig for GET item requires ownership
  // AND the user is NOT an admin (admins can bypass ownership checks).
  if (modelConfig.getItemPermission.requiresOwnershipCheck &&
      !permissionService.isAdmin(authenticatedUser)) {
    // Ensure getOwnerId is provided for models requiring ownership check
    if (modelConfig.getOwnerId == null) {
      print(
        '[ReqID: $requestId] Configuration Error: Model "$modelName" requires '
        'ownership check for GET item but getOwnerId is not provided.',
      );
      // Throw an exception to be caught by the errorHandler
      throw const OperationFailedException(
        'Internal Server Error: Model configuration error.',
      );
    }

    final itemOwnerId = modelConfig.getOwnerId!(item);
    if (itemOwnerId != authenticatedUser.id) {
      // If the authenticated user is not the owner, deny access.
      // Throw ForbiddenException to be caught by the errorHandler
      throw const ForbiddenException(
        'You do not have permission to access this specific item.',
      );
    }
  }

  // Create metadata including the request ID and current timestamp
  final metadata = ResponseMetadata(
    requestId: requestId,
    timestamp: DateTime.now().toUtc(), // Use UTC for consistency
  );

  // Wrap the item in SuccessApiResponse with metadata
  final successResponse = SuccessApiResponse<dynamic>(
    data: item,
    metadata: metadata, // Include the created metadata
  );

  // Provide the correct toJsonT for the specific model type
  final responseJson = successResponse.toJson(
    (item) => (item as dynamic).toJson(), // Assuming all models have toJson
  );

  // Return 200 OK with the wrapped and serialized response
  return Response.json(body: responseJson);
}

// --- PUT Handler ---
/// Handles PUT requests: Updates an existing item by its ID.
/// Includes request metadata in response.
Future<Response> _handlePut(
  RequestContext context,
  String id,
  String modelName,
  ModelConfig<dynamic> modelConfig,
  User authenticatedUser,
  PermissionService permissionService, // Receive PermissionService
  UserPreferenceLimitService
      userPreferenceLimitService, // Receive Limit Service
  String requestId,
) async {
  // Authorization check is handled by authorizationMiddleware before this.
  // This handler only needs to perform the ownership check if required.

  final requestBody = await context.request.json() as Map<String, dynamic>?;
  if (requestBody == null) {
    // Throw BadRequestException to be caught by the errorHandler
    throw const BadRequestException('Missing or invalid request body.');
  }

  // Deserialize using ModelConfig's fromJson, catching TypeErrors locally
  dynamic itemToUpdate;
  try {
    itemToUpdate = modelConfig.fromJson(requestBody);
  } on TypeError catch (e) {
    // Catch errors during deserialization (e.g., missing required fields)
    // Include requestId in the server log
    print(
      '[ReqID: $requestId] Deserialization TypeError in PUT /data/[id]: $e',
    );
    // Throw BadRequestException to be caught by the errorHandler
    throw const BadRequestException(
      'Invalid request body: Missing or invalid required field(s).',
    );
  }

  // Ensure the ID in the path matches the ID in the request body (if present)
  // This is a data integrity check, not an authorization check.
  try {
    final bodyItemId = modelConfig.getId(itemToUpdate);
    if (bodyItemId != id) {
      // Throw BadRequestException to be caught by the errorHandler
      throw BadRequestException(
        'Bad Request: ID in request body ("$bodyItemId") does not match ID in path ("$id").',
      );
    }
  } catch (e) {
    // Ignore if getId throws, means ID might not be in the body,
    // which is acceptable depending on the model/client.
    // Log for debugging if needed.
    print('[ReqID: $requestId] Warning: Could not get ID from PUT body: $e');
  }

  // --- Handler-Level Limit Check (for UserContentPreferences PUT) ---
  // If the model is UserContentPreferences, check if the proposed update
  // exceeds the user's limits before attempting the repository update.
  if (modelName == 'user_content_preferences') {
    try {
      // Ensure the itemToUpdate is the correct type for the limit service
      if (itemToUpdate is! UserContentPreferences) {
        print(
          '[ReqID: $requestId] Type Error: Expected UserContentPreferences '
          'for limit check, but got ${itemToUpdate.runtimeType}.',
        );
        throw const OperationFailedException(
          'Internal Server Error: Model type mismatch for limit check.',
        );
      }
      await userPreferenceLimitService.checkUpdatePreferences(
        authenticatedUser,
        itemToUpdate,
      );
    } on HtHttpException {
      // Propagate known exceptions from the limit service (e.g., ForbiddenException)
      rethrow;
    } catch (e) {
      // Catch unexpected errors from the limit service
      print(
        '[ReqID: $requestId] Unexpected error during limit check for '
        'UserContentPreferences PUT: $e',
      );
      throw const OperationFailedException(
        'An unexpected error occurred during limit check.',
      );
    }
  }

  // Determine userId for repository call based on ModelConfig (for data scoping/ownership enforcement)
  String? userIdForRepoCall;
  // If the model is user-owned, pass the authenticated user's ID to the repository
  // for ownership enforcement. Otherwise, pass null.
  if (modelConfig.getOwnerId != null) {
    userIdForRepoCall = authenticatedUser.id;
  } else {
    userIdForRepoCall = null;
  }

  dynamic updatedItem;

  // Repository exceptions (like NotFoundException, BadRequestException)
  // will propagate up to the errorHandler.
  switch (modelName) {
    case 'headline':
      {
        final repo = context.read<HtDataRepository<Headline>>();
        updatedItem = await repo.update(
          id: id,
          item: itemToUpdate as Headline,
          userId: userIdForRepoCall,
        );
      }
    case 'category':
      {
        final repo = context.read<HtDataRepository<Category>>();
        updatedItem = await repo.update(
          id: id,
          item: itemToUpdate as Category,
          userId: userIdForRepoCall,
        );
      }
    case 'source':
      {
        final repo = context.read<HtDataRepository<Source>>();
        updatedItem = await repo.update(
          id: id,
          item: itemToUpdate as Source,
          userId: userIdForRepoCall,
        );
      }
    case 'country':
      {
        final repo = context.read<HtDataRepository<Country>>();
        updatedItem = await repo.update(
          id: id,
          item: itemToUpdate as Country,
          userId: userIdForRepoCall,
        );
      }
    case 'user':
      {
        final repo = context.read<HtDataRepository<User>>();
        updatedItem = await repo.update(
          id: id,
          item: itemToUpdate as User,
          userId: userIdForRepoCall,
        );
      }
    case 'user_app_settings': // New case for UserAppSettings
      {
        final repo = context.read<HtDataRepository<UserAppSettings>>();
        updatedItem = await repo.update(
          id: id,
          item: itemToUpdate as UserAppSettings,
          userId: userIdForRepoCall,
        );
      }
    case 'user_content_preferences': // New case for UserContentPreferences
      {
        final repo = context.read<HtDataRepository<UserContentPreferences>>();
        updatedItem = await repo.update(
          id: id,
          item: itemToUpdate as UserContentPreferences,
          userId: userIdForRepoCall,
        );
      }
    case 'app_config': // New case for AppConfig (update by admin)
      {
        final repo = context.read<HtDataRepository<AppConfig>>();
        updatedItem = await repo.update(
          id: id,
          item: itemToUpdate as AppConfig,
          userId: userIdForRepoCall, // userId should be null for AppConfig
        );
      }
    default:
      // This case should ideally be caught by middleware, but added for safety
      // Throw an exception to be caught by the errorHandler
      throw OperationFailedException(
        'Unsupported model type "$modelName" reached handler.',
      );
  }

  // --- Handler-Level Ownership Check (for PUT) ---
  // This check is needed if the ModelConfig for PUT requires ownership
  // AND the user is NOT an admin (admins can bypass ownership checks).
  // Note: The repository *might* have already enforced ownership if userId was passed.
  // This handler-level check provides a second layer of defense and is necessary
  // if the repository doesn't fully enforce ownership based on userId alone
  // (e.g., if the repo update method allows admins to update any item even if userId is passed).
  if (modelConfig.putPermission.requiresOwnershipCheck &&
      !permissionService.isAdmin(authenticatedUser)) {
    // Ensure getOwnerId is provided for models requiring ownership check
    if (modelConfig.getOwnerId == null) {
      print(
        '[ReqID: $requestId] Configuration Error: Model "$modelName" requires '
        'ownership check for PUT but getOwnerId is not provided.',
      );
      // Throw an exception to be caught by the errorHandler
      throw const OperationFailedException(
        'Internal Server Error: Model configuration error.',
      );
    }
    // Re-fetch the item to ensure we have the owner ID from the source of truth
    // after the update, or ideally, the update method returns the item with owner ID.
    // Assuming the updatedItem returned by the repo has the owner ID:
    final itemOwnerId = modelConfig.getOwnerId!(updatedItem);
    if (itemOwnerId != authenticatedUser.id) {
      // This scenario should ideally not happen if the repository correctly
      // enforced ownership during the update call when userId was passed.
      // But as a defense-in-depth, we check here.
      print(
        '[ReqID: $requestId] Ownership check failed AFTER PUT for item $id. '
        'Item owner: $itemOwnerId, User: ${authenticatedUser.id}',
      );
      // Throw ForbiddenException to be caught by the errorHandler
      throw const ForbiddenException(
        'You do not have permission to update this specific item.',
      );
    }
  }

  // Create metadata including the request ID and current timestamp
  final metadata = ResponseMetadata(
    requestId: requestId,
    timestamp: DateTime.now().toUtc(), // Use UTC for consistency
  );

  // Wrap the updated item in SuccessApiResponse with metadata
  final successResponse = SuccessApiResponse<dynamic>(
    data: updatedItem,
    metadata: metadata,
  );

  // Provide the correct toJsonT for the specific model type
  final responseJson = successResponse.toJson(
    (item) => (item as dynamic).toJson(), // Assuming all models have toJson
  );

  // Return 200 OK with the wrapped and serialized response
  return Response.json(body: responseJson);
}

// --- DELETE Handler ---
/// Handles DELETE requests: Deletes an item by its ID.
Future<Response> _handleDelete(
  RequestContext context,
  String id,
  String modelName,
  ModelConfig<dynamic> modelConfig,
  User authenticatedUser,
  PermissionService permissionService,
  String requestId,
) async {
  // Authorization check is handled by authorizationMiddleware before this.
  // This handler only needs to perform the ownership check if required.

  // Determine userId for repository call based on ModelConfig (for data scoping/ownership enforcement)
  String? userIdForRepoCall;
  // If the model is user-owned, pass the authenticated user's ID to the repository
  // for ownership enforcement. Otherwise, pass null.
  if (modelConfig.getOwnerId != null) {
    userIdForRepoCall = authenticatedUser.id;
  } else {
    userIdForRepoCall = null;
  }

  // --- Handler-Level Ownership Check (for DELETE) ---
  // For DELETE, we need to fetch the item *before* attempting deletion
  // to perform the ownership check if required.
  dynamic itemToDelete;
  if (modelConfig.deletePermission.requiresOwnershipCheck &&
      !permissionService.isAdmin(authenticatedUser)) {
    // Ensure getOwnerId is provided for models requiring ownership check
    if (modelConfig.getOwnerId == null) {
      print(
        '[ReqID: $requestId] Configuration Error: Model "$modelName" requires '
        'ownership check for DELETE but getOwnerId is not provided.',
      );
      // Throw an exception to be caught by the errorHandler
      throw const OperationFailedException(
        'Internal Server Error: Model configuration error.',
      );
    }
    // Fetch the item to check ownership. Use userIdForRepoCall for scoping.
    // Repository exceptions (like NotFoundException) will propagate up to the errorHandler.
    switch (modelName) {
      case 'headline':
        final repo = context.read<HtDataRepository<Headline>>();
        itemToDelete = await repo.read(id: id, userId: userIdForRepoCall);
      case 'category':
        final repo = context.read<HtDataRepository<Category>>();
        itemToDelete = await repo.read(id: id, userId: userIdForRepoCall);
      case 'source':
        final repo = context.read<HtDataRepository<Source>>();
        itemToDelete = await repo.read(id: id, userId: userIdForRepoCall);
      case 'country':
        final repo = context.read<HtDataRepository<Country>>();
        itemToDelete = await repo.read(id: id, userId: userIdForRepoCall);
      case 'user':
        final repo = context.read<HtDataRepository<User>>();
        itemToDelete = await repo.read(id: id, userId: userIdForRepoCall);
      case 'user_app_settings': // New case for UserAppSettings
        final repo = context.read<HtDataRepository<UserAppSettings>>();
        itemToDelete = await repo.read(id: id, userId: userIdForRepoCall);
      case 'user_content_preferences': // New case for UserContentPreferences
        final repo = context.read<HtDataRepository<UserContentPreferences>>();
        itemToDelete = await repo.read(id: id, userId: userIdForRepoCall);
      case 'app_config': // New case for AppConfig (delete by admin)
        final repo = context.read<HtDataRepository<AppConfig>>();
        itemToDelete = await repo.read(
          id: id,
          userId: userIdForRepoCall,
        ); // userId should be null for AppConfig
      default:
        print(
          '[ReqID: $requestId] Error: Unsupported model type "$modelName" reached _handleDelete ownership check.',
        );
        // Throw an exception to be caught by the errorHandler
        throw OperationFailedException(
          'Unsupported model type "$modelName" reached handler.',
        );
    }

    // Perform the ownership check if the item was found
    if (itemToDelete != null) {
      final itemOwnerId = modelConfig.getOwnerId!(itemToDelete);
      if (itemOwnerId != authenticatedUser.id) {
        // If the authenticated user is not the owner, deny access.
        // Throw ForbiddenException to be caught by the errorHandler
        throw const ForbiddenException(
          'You do not have permission to delete this specific item.',
        );
      }
    }
    // If itemToDelete is null here, it means the item wasn't found during the read.
    // The subsequent delete call will likely throw NotFoundException, which is correct.
  }

  // Allow repository exceptions (e.g., NotFoundException) to propagate
  // upwards to be handled by the standard error handling mechanism.
  switch (modelName) {
    case 'headline':
      await context
          .read<HtDataRepository<Headline>>()
          .delete(id: id, userId: userIdForRepoCall);
    case 'category':
      await context
          .read<HtDataRepository<Category>>()
          .delete(id: id, userId: userIdForRepoCall);
    case 'source':
      await context
          .read<HtDataRepository<Source>>()
          .delete(id: id, userId: userIdForRepoCall);
    case 'country':
      await context
          .read<HtDataRepository<Country>>()
          .delete(id: id, userId: userIdForRepoCall);
    case 'user':
      await context
          .read<HtDataRepository<User>>()
          .delete(id: id, userId: userIdForRepoCall);
    case 'user_app_settings': // New case for UserAppSettings
      await context
          .read<HtDataRepository<UserAppSettings>>()
          .delete(id: id, userId: userIdForRepoCall);
    case 'user_content_preferences': // New case for UserContentPreferences
      await context
          .read<HtDataRepository<UserContentPreferences>>()
          .delete(id: id, userId: userIdForRepoCall);
    case 'app_config': // New case for AppConfig (delete by admin)
      await context.read<HtDataRepository<AppConfig>>().delete(
            id: id,
            userId: userIdForRepoCall,
          ); // userId should be null for AppConfig
    default:
      // This case should ideally be caught by the data/_middleware.dart,
      // but added for safety. Consider logging this unexpected state.
      print(
        '[ReqID: $requestId] Error: Unsupported model type "$modelName" reached _handleDelete.',
      );
      // Throw an exception to be caught by the errorHandler
      throw OperationFailedException(
        'Unsupported model type "$modelName" reached handler.',
      );
  }

  // Return 204 No Content for successful deletion (no body, no metadata)
  return Response(statusCode: HttpStatus.noContent);
}
