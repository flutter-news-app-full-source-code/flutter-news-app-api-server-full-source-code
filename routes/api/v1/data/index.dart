//
// ignore_for_file: lines_longer_than_80_chars, no_default_cases, avoid_catches_without_on_clauses, avoid_catching_errors

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
// Import RequestId from the middleware file where it's defined
import 'package:ht_api/src/registry/model_registry.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_http_client/ht_http_client.dart'; // Import exceptions
// Import models, SuccessApiResponse, PaginatedResponse, ResponseMetadata
import 'package:ht_shared/ht_shared.dart';

import '../../../_middleware.dart';

/// Handles requests for the /api/v1/data collection endpoint.
/// Dispatches requests to specific handlers based on the HTTP method.
Future<Response> onRequest(RequestContext context) async {
  // Read dependencies provided by middleware
  final modelName = context.read<String>();
  // Read ModelConfig for fromJson (needed for POST)
  final modelConfig = context.read<ModelConfig<dynamic>>();
  // Read the unique RequestId provided by the root middleware
  // Note: This assumes RequestId is always provided by `routes/_middleware.dart`
  final requestId = context.read<RequestId>().id;

  try {
    switch (context.request.method) {
      case HttpMethod.get:
        // Pass requestId down to the handler
        return await _handleGet(context, modelName, requestId);
      case HttpMethod.post:
        // Pass requestId down to the handler
        return await _handlePost(context, modelName, modelConfig, requestId);
      // Add cases for other methods if needed in the future
      default:
        // Methods not allowed on the collection endpoint
        return Response(statusCode: HttpStatus.methodNotAllowed);
    }
  } on HtHttpException catch (_) {
    // Let the errorHandler middleware handle HtHttpExceptions
    rethrow;
  } on FormatException catch (_) {
    // Let the errorHandler middleware handle FormatExceptions
    rethrow;
  } catch (e, stackTrace) {
    // Handle any other unexpected errors locally (e.g., provider resolution)
    // Include requestId in the server log for easier debugging
    print(
      '[ReqID: $requestId] Unexpected error in /data/index.dart handler: $e\n$stackTrace',
    );
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: 'Internal Server Error.',
    );
  }
}

// --- GET Handler ---
/// Handles GET requests: Retrieves all items for the specified model
/// (with optional query/pagination). Includes request metadata in response.
Future<Response> _handleGet(
  RequestContext context,
  String modelName,
  String requestId, // Receive requestId
) async {
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
  PaginatedResponse<dynamic> paginatedResponse; // Use dynamic for the list
  try {
    switch (modelName) {
      case 'headline':
        final repo = context.read<HtDataRepository<Headline>>();
        paginatedResponse = specificQuery.isNotEmpty
            ? await repo.readAllByQuery(
                specificQuery,
                startAfterId: startAfterId,
                limit: limit,
              )
            : await repo.readAll(startAfterId: startAfterId, limit: limit);
      case 'category':
        final repo = context.read<HtDataRepository<Category>>();
        paginatedResponse = specificQuery.isNotEmpty
            ? await repo.readAllByQuery(
                specificQuery,
                startAfterId: startAfterId,
                limit: limit,
              )
            : await repo.readAll(startAfterId: startAfterId, limit: limit);
      case 'source':
        final repo = context.read<HtDataRepository<Source>>();
        paginatedResponse = specificQuery.isNotEmpty
            ? await repo.readAllByQuery(
                specificQuery,
                startAfterId: startAfterId,
                limit: limit,
              )
            : await repo.readAll(startAfterId: startAfterId, limit: limit);
      case 'country':
        final repo = context.read<HtDataRepository<Country>>();
        paginatedResponse = specificQuery.isNotEmpty
            ? await repo.readAllByQuery(
                specificQuery,
                startAfterId: startAfterId,
                limit: limit,
              )
            : await repo.readAll(startAfterId: startAfterId, limit: limit);
      default:
        // This case should be caught by middleware, but added for safety
        return Response(
          statusCode: HttpStatus.internalServerError,
          body:
              'Internal Server Error: Unsupported model type "$modelName" reached handler.',
        );
    }
  } catch (e) {
    // Catch potential provider errors during context.read within this handler
    // Include requestId in the server log
    print(
      '[ReqID: $requestId] Error reading repository provider for model "$modelName" in _handleGet: $e',
    );
    return Response(
      statusCode: HttpStatus.internalServerError,
      body:
          'Internal Server Error: Could not resolve repository for model "$modelName".',
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
  String requestId, // Receive requestId
) async {
  final requestBody = await context.request.json() as Map<String, dynamic>?;
  if (requestBody == null) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Missing or invalid request body.',
    );
  }

  // Deserialize using ModelConfig's fromJson, catching TypeErrors
  dynamic newItem; // Use dynamic initially
  try {
    newItem = modelConfig.fromJson(requestBody);
  } on TypeError catch (e) {
    // Catch errors during deserialization (e.g., missing required fields)
    // Include requestId in the server log
    print('[ReqID: $requestId] Deserialization TypeError in POST /data: $e');
    return Response.json(
      statusCode: HttpStatus.badRequest, // 400
      body: {
        'error': {
          'code': 'INVALID_REQUEST_BODY',
          'message':
              'Invalid request body: Missing or invalid required field(s).',
          // 'details': e.toString(), // Optional: Include details in dev
        },
      },
    );
  }

  // Process based on model type
  dynamic createdItem; // Use dynamic
  // Repository exceptions (like BadRequestException from create) will propagate
  // up to the main onRequest try/catch and be re-thrown to the middleware.
  try {
    switch (modelName) {
      case 'headline':
        final repo = context.read<HtDataRepository<Headline>>();
        createdItem = await repo.create(newItem as Headline);
      case 'category':
        final repo = context.read<HtDataRepository<Category>>();
        createdItem = await repo.create(newItem as Category);
      case 'source':
        final repo = context.read<HtDataRepository<Source>>();
        createdItem = await repo.create(newItem as Source);
      case 'country':
        final repo = context.read<HtDataRepository<Country>>();
        createdItem = await repo.create(newItem as Country);
      default:
        // This case should ideally be caught by middleware, but added for safety
        return Response(
          statusCode: HttpStatus.internalServerError,
          body:
              'Internal Server Error: Unsupported model type "$modelName" reached handler.',
        );
    }
  } catch (e) {
    // Catch potential provider errors during context.read within this handler
    // Include requestId in the server log
    print(
      '[ReqID: $requestId] Error reading repository provider for model "$modelName" in _handlePost: $e',
    );
    return Response(
      statusCode: HttpStatus.internalServerError,
      body:
          'Internal Server Error: Could not resolve repository for model "$modelName".',
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
    metadata: metadata, // Include the created metadata
  );

  // Provide the correct toJsonT for the specific model type
  final responseJson = successResponse.toJson(
    (item) => (item as dynamic).toJson(), // Assuming all models have toJson
  );

  // Return 201 Created with the wrapped and serialized response
  return Response.json(statusCode: HttpStatus.created, body: responseJson);
}
