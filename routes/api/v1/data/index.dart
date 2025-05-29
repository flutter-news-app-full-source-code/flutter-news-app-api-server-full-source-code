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
/// Handles GET requests: Retrieves all items for the specified model.
///
/// This handler implements model-specific filtering rules:
/// - **Headlines (`model=headline`):**
///   - Filterable by `q` (text query on title only).
///     If `q` is present, `categories` and `sources` are ignored.
///     Example: `/api/v1/data?model=headline&q=Dart+Frog`
///   - OR by a combination of:
///     - `categories` (comma-separated category IDs).
///       Example: `/api/v1/data?model=headline&categories=catId1,catId2`
///     - `sources` (comma-separated source IDs).
///       Example: `/api/v1/data?model=headline&sources=sourceId1`
///     - Both `categories` and `sources` can be used together (AND logic).
///       Example: `/api/v1/data?model=headline&categories=catId1&sources=sourceId1`
///   - Other parameters for headlines (e.g., `countries`) will result in a 400 Bad Request.
///
/// - **Sources (`model=source`):**
///   - Filterable by `q` (text query on name only).
///     If `q` is present, `countries`, `sourceTypes`, `languages` are ignored.
///     Example: `/api/v1/data?model=source&q=Tech+News`
///   - OR by a combination of:
///     - `countries` (comma-separated country ISO codes for `source.headquarters.iso_code`).
///       Example: `/api/v1/data?model=source&countries=US,GB`
///     - `sourceTypes` (comma-separated `SourceType` enum string values for `source.sourceType`).
///       Example: `/api/v1/data?model=source&sourceTypes=blog,news_agency`
///     - `languages` (comma-separated language codes for `source.language`).
///       Example: `/api/v1/data?model=source&languages=en,fr`
///   - These specific filters are ANDed if multiple are provided.
///   - Other parameters for sources will result in a 400 Bad Request.
///
/// - **Categories (`model=category`):**
///   - Filterable ONLY by `q` (text query on name only).
///     Example: `/api/v1/data?model=category&q=Technology`
///   - Other parameters for categories will result in a 400 Bad Request.
///
/// - **Countries (`model=country`):**
///   - Filterable ONLY by `q` (text query on name only).
///     Example: `/api/v1/data?model=country&q=United`
///   - Other parameters for countries will result in a 400 Bad Request.
///
/// - **Other Models (User, UserAppSettings, UserContentPreferences, AppConfig):**
///   - Currently support exact match for top-level query parameters passed directly.
///   - No specific complex filtering logic (like `_in` or `_contains`) is applied
///     by this handler for these models yet. The `HtDataInMemoryClient` can
///     process such queries if the `specificQueryForClient` map is constructed
///     with the appropriate keys by this handler in the future.
///
/// Includes request metadata in the response.
Future<Response> _handleGet(
  RequestContext context,
  String modelName,
  ModelConfig<dynamic> modelConfig,
  User authenticatedUser,
  PermissionService permissionService,
  String requestId,
) async {
  final queryParams = context.request.uri.queryParameters;
  final startAfterId = queryParams['startAfterId'];
  final limitParam = queryParams['limit'];
  final limit = limitParam != null ? int.tryParse(limitParam) : null;

  final specificQueryForClient = <String, String>{};
  final Set<String> allowedKeys;
  final receivedKeys = queryParams.keys
      .where((k) => k != 'model' && k != 'startAfterId' && k != 'limit')
      .toSet();

  switch (modelName) {
    case 'headline':
      allowedKeys = {'categories', 'sources', 'q'};
      final qValue = queryParams['q'];
      if (qValue != null && qValue.isNotEmpty) {
        specificQueryForClient['title_contains'] = qValue;
        // specificQueryForClient['description_contains'] = qValue; // Removed
      } else {
        if (queryParams.containsKey('categories')) {
          specificQueryForClient['category.id_in'] = queryParams['categories']!;
        }
        if (queryParams.containsKey('sources')) {
          specificQueryForClient['source.id_in'] = queryParams['sources']!;
        }
      }
    case 'source':
      allowedKeys = {'countries', 'sourceTypes', 'languages', 'q'};
      final qValue = queryParams['q'];
      if (qValue != null && qValue.isNotEmpty) {
        specificQueryForClient['name_contains'] = qValue;
        // specificQueryForClient['description_contains'] = qValue; // Removed
      } else {
        if (queryParams.containsKey('countries')) {
          specificQueryForClient['headquarters.iso_code_in'] =
              queryParams['countries']!;
        }
        if (queryParams.containsKey('sourceTypes')) {
          specificQueryForClient['source_type_in'] =
              queryParams['sourceTypes']!;
        }
        if (queryParams.containsKey('languages')) {
          specificQueryForClient['language_in'] = queryParams['languages']!;
        }
      }
    case 'category':
      allowedKeys = {'q'};
      final qValue = queryParams['q'];
      if (qValue != null && qValue.isNotEmpty) {
        specificQueryForClient['name_contains'] = qValue;
        // specificQueryForClient['description_contains'] = qValue; // Removed
      }
    case 'country':
      allowedKeys = {'q'};
      final qValue = queryParams['q'];
      if (qValue != null && qValue.isNotEmpty) {
        specificQueryForClient['name_contains'] = qValue;
        // specificQueryForClient['iso_code_contains'] = qValue; // Removed
      }
    default:
      // For other models, pass through all non-standard query params directly.
      // No specific validation of allowed keys for these other models here.
      // The client will attempt exact matches.
      allowedKeys = receivedKeys; // Effectively allows all received keys
      queryParams.forEach((key, value) {
        if (key != 'model' && key != 'startAfterId' && key != 'limit') {
          specificQueryForClient[key] = value;
        }
      });
  }

  // Validate received keys against allowed keys for the specific models
  if (modelName == 'headline' ||
      modelName == 'source' ||
      modelName == 'category' ||
      modelName == 'country') {
    for (final key in receivedKeys) {
      if (!allowedKeys.contains(key)) {
        throw BadRequestException(
          'Invalid query parameter "$key" for model "$modelName". '
          'Allowed parameters are: ${allowedKeys.join(', ')}.',
        );
      }
    }
  }

  PaginatedResponse<dynamic> paginatedResponse;
  // ignore: prefer_final_locals
  var userIdForRepoCall =
      modelConfig.getOwnerId != null ? authenticatedUser.id : null;

  // Repository calls using specificQueryForClient
  switch (modelName) {
    case 'headline':
      final repo = context.read<HtDataRepository<Headline>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient,
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
      );
    case 'category':
      final repo = context.read<HtDataRepository<Category>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient,
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
      );
    case 'source':
      final repo = context.read<HtDataRepository<Source>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient,
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
      );
    case 'country':
      final repo = context.read<HtDataRepository<Country>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient,
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
      );
    case 'user':
      final repo = context.read<HtDataRepository<User>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient, // Pass the potentially empty map
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
      );
    case 'user_app_settings':
      final repo = context.read<HtDataRepository<UserAppSettings>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient,
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
      );
    case 'user_content_preferences':
      final repo = context.read<HtDataRepository<UserContentPreferences>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient,
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
      );
    case 'app_config':
      final repo = context.read<HtDataRepository<AppConfig>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient,
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
      );
    default:
      throw OperationFailedException(
        'Unsupported model type "$modelName" reached data retrieval switch.',
      );
  }

  final finalFeedItems = paginatedResponse.items;
  final metadata = ResponseMetadata(
    requestId: requestId,
    timestamp: DateTime.now().toUtc(), // Use UTC for consistency
  );

  // Wrap the PaginatedResponse in SuccessApiResponse with metadata
  final successResponse = SuccessApiResponse<PaginatedResponse<dynamic>>(
    data: PaginatedResponse<dynamic>(
      items: finalFeedItems, // Items are already dynamic
      cursor: paginatedResponse.cursor,
      hasMore: paginatedResponse.hasMore,
    ),
    metadata: metadata,
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
  PermissionService permissionService,
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
