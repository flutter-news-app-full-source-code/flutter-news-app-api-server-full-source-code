import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/rbac/permission_service.dart'; // Import PermissionService
import 'package:ht_api/src/registry/model_registry.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_shared/ht_shared.dart';

import '../../../_middleware.dart'; // Assuming RequestId is here

/// Handles requests for the /api/v1/data collection endpoint.
/// Dispatches requests to specific handlers based on the HTTP method.
Future<Response> onRequest(RequestContext context) async {
  // Read dependencies provided by middleware
  final modelName = context.read<String>();
  final modelConfig = context.read<ModelConfig<dynamic>>();
  final requestId = context.read<RequestId>().id;
  // User is guaranteed non-null by requireAuthentication() middleware
  final authenticatedUser = context.read<User>();
  final permissionService =
      context.read<PermissionService>(); // Read PermissionService

  // The main try/catch block here is removed to let the errorHandler middleware
  // handle all exceptions thrown by the handlers below.
  switch (context.request.method) {
    case HttpMethod.get:
      return _handleGet(
        context,
        modelName,
        modelConfig,
        authenticatedUser,
        permissionService, // Pass PermissionService
        requestId,
      );
    case HttpMethod.post:
      return _handlePost(
        context,
        modelName,
        modelConfig,
        authenticatedUser,
        permissionService, // Pass PermissionService
        requestId,
      );
    // Add cases for other methods if needed in the future
    default:
      // Methods not allowed on the collection endpoint
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

// --- GET Handler ---
/// Handles GET requests: Retrieves all items for the specified model
/// (with optional query/pagination). Includes request metadata in response.
Future<Response> _handleGet(
  RequestContext context,
  String modelName,
  ModelConfig<dynamic> modelConfig,
  User authenticatedUser,
  PermissionService permissionService, // Receive PermissionService
  String requestId,
) async {
  // Authorization check is handled by authorizationMiddleware before this.
  // This handler only needs to perform the ownership check if required.

  // Read query parameters
  final queryParams = context.request.uri.queryParameters;
  final startAfterId = queryParams['startAfterId'];
  final limitParam = queryParams['limit'];
  final limit = limitParam != null ? int.tryParse(limitParam) : null;
  final specificQuery = Map<String, dynamic>.from(queryParams)
    ..remove('model')
    ..remove('startAfterId')
    ..remove('limit');

  // Process based on model type
  PaginatedResponse<dynamic> paginatedResponse;

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

  // Repository exceptions (like NotFoundException, BadRequestException)
  // will propagate up to the errorHandler.
  switch (modelName) {
    case 'headline':
      final repo = context.read<HtDataRepository<Headline>>();
      paginatedResponse = specificQuery.isNotEmpty
          ? await repo.readAllByQuery(
              specificQuery,
              userId: userIdForRepoCall,
              startAfterId: startAfterId,
              limit: limit,
            )
          : await repo.readAll(
              userId: userIdForRepoCall,
              startAfterId: startAfterId,
              limit: limit,
            );
    case 'category':
      final repo = context.read<HtDataRepository<Category>>();
      paginatedResponse = specificQuery.isNotEmpty
          ? await repo.readAllByQuery(
              specificQuery,
              userId: userIdForRepoCall,
              startAfterId: startAfterId,
              limit: limit,
            )
          : await repo.readAll(
              userId: userIdForRepoCall,
              startAfterId: startAfterId,
              limit: limit,
            );
    case 'source':
      final repo = context.read<HtDataRepository<Source>>();
      paginatedResponse = specificQuery.isNotEmpty
          ? await repo.readAllByQuery(
              specificQuery,
              userId: userIdForRepoCall,
              startAfterId: startAfterId,
              limit: limit,
            )
          : await repo.readAll(
              userId: userIdForRepoCall,
              startAfterId: startAfterId,
              limit: limit,
            );
    case 'country':
      final repo = context.read<HtDataRepository<Country>>();
      paginatedResponse = specificQuery.isNotEmpty
          ? await repo.readAllByQuery(
              specificQuery,
              userId: userIdForRepoCall,
              startAfterId: startAfterId,
              limit: limit,
            )
          : await repo.readAll(
              userId: userIdForRepoCall,
              startAfterId: startAfterId,
              limit: limit,
            );
    case 'user':
      final repo = context.read<HtDataRepository<User>>();
      // Note: While readAll/readAllByQuery is used here for consistency
      // with the generic endpoint, fetching a specific user by ID via
      // the /data/[id] route is the semantically preferred method.
      // The userIdForRepoCall ensures scoping to the authenticated user
      // if the repository supports it.
      paginatedResponse = specificQuery.isNotEmpty
          ? await repo.readAllByQuery(
              specificQuery,
              userId: userIdForRepoCall,
              startAfterId: startAfterId,
              limit: limit,
            )
          : await repo.readAll(
              userId: userIdForRepoCall,
              startAfterId: startAfterId,
              limit: limit,
            );
    case 'user_app_settings':
      final repo = context.read<HtDataRepository<UserAppSettings>>();
      // Note: While readAll/readAllByQuery is used here for consistency
      // with the generic endpoint, fetching the user's settings by ID
      // via the /data/[id] route is the semantically preferred method
      // for this single-instance, user-owned model.
      paginatedResponse = specificQuery.isNotEmpty
          ? await repo.readAllByQuery(
              specificQuery,
              userId: userIdForRepoCall,
              startAfterId: startAfterId,
              limit: limit,
            )
          : await repo.readAll(
              userId: userIdForRepoCall,
              startAfterId: startAfterId,
              limit: limit,
            );
    case 'user_content_preferences':
      final repo = context.read<HtDataRepository<UserContentPreferences>>();
      // Note: While readAll/readAllByQuery is used here for consistency
      // with the generic endpoint, fetching the user's preferences by ID
      // via the /data/[id] route is the semantically preferred method
      // for this single-instance, user-owned model.
      paginatedResponse = specificQuery.isNotEmpty
          ? await repo.readAllByQuery(
              specificQuery,
              userId: userIdForRepoCall,
              startAfterId: startAfterId,
              limit: limit,
            )
          : await repo.readAll(
              userId: userIdForRepoCall,
              startAfterId: startAfterId,
              limit: limit,
            );
    case 'app_config':
      final repo = context.read<HtDataRepository<AppConfig>>();
      // Note: While readAll/readAllByQuery is used here for consistency
      // with the generic endpoint, fetching the single AppConfig instance
      // by its fixed ID ('app_config') via the /data/[id] route is the
      // semantically preferred method for this global singleton model.
      paginatedResponse = specificQuery.isNotEmpty
          ? await repo.readAllByQuery(
              specificQuery,
              userId: userIdForRepoCall, // userId should be null for AppConfig
              startAfterId: startAfterId,
              limit: limit,
            )
          : await repo.readAll(
              userId: userIdForRepoCall, // userId should be null for AppConfig
              startAfterId: startAfterId,
              limit: limit,
            );
    default:
      // This case should be caught by middleware, but added for safety
      // Throw an exception to be caught by the errorHandler
      throw OperationFailedException(
        'Unsupported model type "$modelName" reached handler.',
      );
  }

  // Create metadata including the request ID and current timestamp
  final metadata = ResponseMetadata(
    requestId: requestId,
    timestamp: DateTime.now().toUtc(), // Use UTC for consistency
  );

  // Wrap the PaginatedResponse in SuccessApiResponse with metadata
  final successResponse = SuccessApiResponse<PaginatedResponse<dynamic>>(
    data: paginatedResponse,
    metadata: metadata, // Include the created metadata
  );

  // Need to provide the correct toJsonT for PaginatedResponse
  final responseJson = successResponse.toJson(
    (paginated) => paginated.toJson(
      (item) => (item as dynamic).toJson(), // Assuming all models have toJson
    ),
  );

  // Return 200 OK with the wrapped and serialized response
  return Response.json(body: responseJson);
}

// --- POST Handler ---
/// Handles POST requests: Creates a new item for the specified model.
/// Includes request metadata in response.
Future<Response> _handlePost(
  RequestContext context,
  String modelName,
  ModelConfig<dynamic> modelConfig,
  User authenticatedUser,
  PermissionService permissionService, // Receive PermissionService
  String requestId,
) async {
  // Authorization check is handled by authorizationMiddleware before this.

  final requestBody = await context.request.json() as Map<String, dynamic>?;
  if (requestBody == null) {
    // Throw BadRequestException to be caught by the errorHandler
    throw const BadRequestException('Missing or invalid request body.');
  }

  // Deserialize using ModelConfig's fromJson, catching TypeErrors
  dynamic newItem;
  try {
    newItem = modelConfig.fromJson(requestBody);
  } on TypeError catch (e) {
    // Catch errors during deserialization (e.g., missing required fields)
    // Include requestId in the server log
    print('[ReqID: $requestId] Deserialization TypeError in POST /data: $e');
    // Throw BadRequestException to be caught by the errorHandler
    throw const BadRequestException(
      'Invalid request body: Missing or invalid required field(s).',
    );
  }

  // Determine userId for repository call based on ModelConfig (for data scoping/ownership enforcement)
  String? userIdForRepoCall;
  // If the model is user-owned, pass the authenticated user's ID to the repository
  // for associating ownership during creation. Otherwise, pass null.
  // We infer user-owned based on the presence of getOwnerId function.
  if (modelConfig.getOwnerId != null) {
    userIdForRepoCall = authenticatedUser.id;
  } else {
    userIdForRepoCall = null;
  }

  // Process based on model type
  dynamic createdItem;

  // Repository exceptions (like BadRequestException from create) will propagate
  // up to the errorHandler.
  switch (modelName) {
    case 'headline':
      final repo = context.read<HtDataRepository<Headline>>();
      createdItem = await repo.create(
        item: newItem as Headline,
        userId: userIdForRepoCall,
      );
    case 'category':
      final repo = context.read<HtDataRepository<Category>>();
      createdItem = await repo.create(
        item: newItem as Category,
        userId: userIdForRepoCall,
      );
    case 'source':
      final repo = context.read<HtDataRepository<Source>>();
      createdItem = await repo.create(
        item: newItem as Source,
        userId: userIdForRepoCall,
      );
    case 'country':
      final repo = context.read<HtDataRepository<Country>>();
      createdItem = await repo.create(
        item: newItem as Country,
        userId: userIdForRepoCall,
      );
    case 'user': // Handle User model specifically if needed, or rely on generic
      // User creation is typically handled by auth routes, not generic data POST.
      // Throw Forbidden or BadRequest if attempted here.
      throw const ForbiddenException(
        'User creation is not allowed via the generic data endpoint.',
      );
    case 'user_app_settings': // New case for UserAppSettings
      // Creation of UserAppSettings is handled by auth service, not generic data POST.
      throw const ForbiddenException(
        'UserAppSettings creation is not allowed via the generic data endpoint.',
      );
    case 'user_content_preferences': // New case for UserContentPreferences
      // Creation of UserContentPreferences is handled by auth service, not generic data POST.
      throw const ForbiddenException(
        'UserContentPreferences creation is not allowed via the generic data endpoint.',
      );
    case 'app_config': // New case for AppConfig (create by admin)
      final repo = context.read<HtDataRepository<AppConfig>>();
      createdItem = await repo.create(
        item: newItem as AppConfig,
        userId: userIdForRepoCall, // userId should be null for AppConfig
      );
    default:
      // This case should ideally be caught by middleware, but added for safety
      // Throw an exception to be caught by the errorHandler
      throw OperationFailedException(
        'Unsupported model type "$modelName" reached handler.',
      );
  }

  // Create metadata including the request ID and current timestamp
  final metadata = ResponseMetadata(
    requestId: requestId,
    timestamp: DateTime.now().toUtc(), // Use UTC for consistency
  );

  // Wrap the created item in SuccessApiResponse with metadata
  final successResponse = SuccessApiResponse<dynamic>(
    data: createdItem,
    metadata: metadata,
  );

  // Provide the correct toJsonT for the specific model type
  final responseJson = successResponse.toJson(
    (item) => (item as dynamic).toJson(), // Assuming all models have toJson
  );

  // Return 201 Created with the wrapped and serialized response
  return Response.json(statusCode: HttpStatus.created, body: responseJson);
}
