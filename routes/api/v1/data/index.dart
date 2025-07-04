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
  final permissionService = context
      .read<PermissionService>(); // Read PermissionService

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
///   - Filterable ONLY by `q` (text query on name and isoCode).
///     Example: `/api/v1/data?model=country&q=United` (searches name and isoCode)
///     Example: `/api/v1/data?model=country&q=US` (searches name and isoCode)
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
  final sortBy = queryParams['sortBy'];
  final sortOrderRaw = queryParams['sortOrder']?.toLowerCase();
  final limit = limitParam != null ? int.tryParse(limitParam) : null;

  SortOrder? sortOrder;
  if (sortOrderRaw != null) {
    if (sortOrderRaw == 'asc') {
      sortOrder = SortOrder.asc;
    } else if (sortOrderRaw == 'desc') {
      sortOrder = SortOrder.desc;
    } else {
      throw const BadRequestException(
        'Invalid "sortOrder" parameter. Must be "asc" or "desc".',
      );
    }
  }

  final specificQueryForClient = <String, String>{};
  final Set<String> allowedKeys;
  final receivedKeys = queryParams.keys
      .where(
        (k) =>
            k != 'model' &&
            k != 'startAfterId' &&
            k != 'limit' &&
            k != 'sortBy' &&
            k != 'sortOrder',
      )
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
        specificQueryForClient['iso_code_contains'] = qValue; // Added back
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
  var userIdForRepoCall = modelConfig.getOwnerId != null
      ? authenticatedUser.id
      : null;

  // Repository calls using specificQueryForClient
  switch (modelName) {
    case 'headline':
      final repo = context.read<HtDataRepository<Headline>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient,
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    case 'category':
      final repo = context.read<HtDataRepository<Category>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient,
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    case 'source':
      final repo = context.read<HtDataRepository<Source>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient,
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    case 'country':
      final repo = context.read<HtDataRepository<Country>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient,
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    case 'user':
      final repo = context.read<HtDataRepository<User>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient, // Pass the potentially empty map
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    case 'user_app_settings':
      final repo = context.read<HtDataRepository<UserAppSettings>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient,
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    case 'user_content_preferences':
      final repo = context.read<HtDataRepository<UserContentPreferences>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient,
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    case 'app_config':
      final repo = context.read<HtDataRepository<AppConfig>>();
      paginatedResponse = await repo.readAllByQuery(
        specificQueryForClient,
        userId: userIdForRepoCall,
        startAfterId: startAfterId,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
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

/*
Simplified Strict Filtering Rules (ALL FILTERS ARE ANDed if present):

1. Headlines (`model=headline`):
   - Filterable by any combination (ANDed) of:
     - `categories` (plural, comma-separated IDs, matching `headline.category.id`)
     - `sources` (plural, comma-separated IDs, matching `headline.source.id`)
     - `q` (free-text query, searching `headline.title` only)
   - *No other filters (like `countries`) are allowed for headlines.*

2. Sources (`model=source`):
   - Filterable by any combination (ANDed) of:
     - `countries` (plural, comma-separated ISO codes, matching `source.headquarters.iso_code`)
     - `sourceTypes` (plural, comma-separated enum strings, matching `source.sourceType`)
     - `languages` (plural, comma-separated language codes, matching `source.language`)
     - `q` (free-text query, searching `source.name` only)

3. Categories (`model=category`):
   - Filterable __only__ by:
     - `q` (free-text query, searching `category.name` only)

4. Countries (`model=country`):
   - Filterable __only__ by:
     - `q` (free-text query, searching `country.name` only)

------

Explicitly Define Allowed Parameters per Model: When processing the request for a given `modelName`, the handler should have a predefined set of *allowed* query parameter keys for that specific model.

- Example for `modelName == 'headline'`:
  - Allowed keys: `categories`, `sources`, `q` (plus standard ones like `limit`, `startAfterId`).
- Example for `modelName == 'source'`:
  - Allowed keys: `countries`, `sourceTypes`, `languages`, `q` (plus standard ones).
- And so on for `category` and `country`.

----------------- TESTED FILTERS ---------------

Model: `headline`

1. Filter by single category:
   - URL: `/api/v1/data?model=headline&categories=c1a2b3c4-d5e6-f789-0123-456789abcdef`
   - Expected: Headlines with category ID `c1a2b3c4-d5e6-f789-0123-456789abcdef`.

2. Filter by multiple comma-separated categories (client-side `_in` implies OR for values):
   - URL: `/api/v1/data?model=headline&categories=c1a2b3c4-d5e6-f789-0123-456789abcdef,c2b3c4d5-e6f7-a890-1234-567890abcdef`
   - Expected: Headlines whose category ID is *either* of the two provided.

3. Filter by single source:
   - URL: `/api/v1/data?model=headline&sources=s1a2b3c4-d5e6-f789-0123-456789abcdef`
   - Expected: Headlines with source ID `s1a2b3c4-d5e6-f789-0123-456789abcdef`.

4. Filter by multiple comma-separated sources (client-side `_in` implies OR for values):
   - URL: `/api/v1/data?model=headline&sources=s1a2b3c4-d5e6-f789-0123-456789abcdef,s2b3c4d5-e6f7-a890-1234-567890abcdef`
   - Expected: Headlines whose source ID is *either* of the two provided.

5. Filter by a category AND a source:
   - URL: `/api/v1/data?model=headline&categories=c1a2b3c4-d5e6-f789-0123-456789abcdef&sources=s1a2b3c4-d5e6-f789-0123-456789abcdef`
   - Expected: Headlines matching *both* the category ID AND the source ID.

6. Filter by text query `q` (title only):
   - URL: `/api/v1/data?model=headline&q=Dart`
   - Expected: Headlines where "Dart" (case-insensitive) appears in the title.

7. Filter by `q` AND `categories` (q should take precedence, categories ignored):
   - URL: `/api/v1/data?model=headline&q=Flutter&categories=c1a2b3c4-d5e6-f789-0123-456789abcdef`
   - Expected: Headlines matching `q=Flutter` (in title), ignoring the category filter.

8. Invalid parameter for headlines (e.g., `countries`):
   - URL: `/api/v1/data?model=headline&countries=US`
   - Expected: `400 Bad Request` with an error message about an invalid query parameter.

Model: `source`

9. Filter by single country (ISO code):
   - URL: `/api/v1/data?model=source&countries=GB`
   - Expected: Sources headquartered in 'GB'.

10. Filter by multiple comma-separated countries (client-side `_in` implies OR for values):
    - URL: `/api/v1/data?model=source&countries=US,GB`
    - Expected: Sources headquartered in 'US' OR 'GB'.

11. Filter by single `sourceType`:
    - URL: `/api/v1/data?model=source&sourceTypes=blog`
    - Expected: Sources of type 'blog'.

12. Filter by multiple comma-separated `sourceTypes` (client-side `_in` implies OR for values):
    - URL: `/api/v1/data?model=source&sourceTypes=blog,specializedPublisher`
    - Expected: Sources of type 'blog' OR 'specializedPublisher'.

13. Filter by single `language`:
    - URL: `/api/v1/data?model=source&languages=en`
    - Expected: Sources in 'en' language.

14. Filter by combination (countries AND sourceTypes AND languages):
    - URL: `/api/v1/data?model=source&countries=GB&sourceTypes=nationalNewsOutlet&languages=en`
    - Expected: Sources matching all three criteria.

15. Filter by text query `q` for sources (name only):
    - URL: `/api/v1/data?model=source&q=Ventures`
    - Expected: Sources where "Ventures" appears in the name.

16. Filter by `q` AND `countries` for sources (`q` takes precedence):
    - URL: `/api/v1/data?model=source&q=Official&countries=US`
    - Expected: Sources matching `q=Official` (in name), ignoring the country filter.

17. Invalid parameter for sources (e.g., `categories`):
    - URL: `/api/v1/data?model=source&categories=catId1`
    - Expected: `400 Bad Request`.

Model: `category`

18. Filter by text query `q` for categories (name only):
    - URL: `/api/v1/data?model=category&q=Mobile`
    - Expected: Categories where "Mobile" appears in name.

19. Invalid parameter for categories (e.g., `sources`):
    - URL: `/api/v1/data?model=category&sources=sourceId1`
    - Expected: `400 Bad Request`.

Model: `country`

20. Filter by text query `q` for countries (name and iso_code):
    - URL: `/api/v1/data?model=country&q=United`
    - Expected: Countries where "United" appears in the name.

21. Filter by text query `q` for countries (name and iso_code):
    - URL: `/api/v1/data?model=country&q=US`
    - Expected: Country with name containing "US". (Note: This test's expectation might need adjustment if no country name contains "US" but its isoCode is "US". The current `q` logic for country only searches name).

22. Invalid parameter for countries (e.g., `categories`):
    - URL: `/api/v1/data?model=country&categories=catId1`
    - Expected: `400 Bad Request`.
*/
