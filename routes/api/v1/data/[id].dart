import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
// Import RequestId from the middleware file where it's defined
import 'package:ht_api/src/registry/model_registry.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_http_client/ht_http_client.dart'; // Import exceptions
// Import models, SuccessApiResponse, ResponseMetadata
import 'package:ht_shared/ht_shared.dart';

import '../../../_middleware.dart';

/// Handles requests for the /api/v1/data/[id] endpoint.
/// Dispatches requests to specific handlers based on the HTTP method.
Future<Response> onRequest(RequestContext context, String id) async {
  // Read dependencies provided by middleware
  final modelName = context.read<String>();
  // Read ModelConfig for fromJson (needed for PUT)
  final modelConfig = context.read<ModelConfig<dynamic>>();
  // Read the unique RequestId provided by the root middleware
  final requestId = context.read<RequestId>().id;

  try {
    switch (context.request.method) {
      case HttpMethod.get:
        // Pass requestId down to the handler
        return await _handleGet(context, id, modelName, requestId);
      case HttpMethod.put:
        // Pass requestId down to the handler
        return await _handlePut(context, id, modelName, modelConfig, requestId);
      case HttpMethod.delete:
        // DELETE doesn't return a body, so no metadata needed here
        return await _handleDelete(context, id, modelName, requestId);
      // Add cases for other methods if needed in the future
      default:
        // Methods not allowed on the item endpoint
        return Response(statusCode: HttpStatus.methodNotAllowed);
    }
  } on HtHttpException catch (_) {
    // Let the errorHandler middleware handle HtHttpExceptions (incl. NotFound)
    rethrow;
  } on FormatException catch (_) {
    // Let the errorHandler middleware handle FormatExceptions (e.g., from PUT body)
    rethrow;
  } catch (e, stackTrace) {
    // Handle any other unexpected errors locally (e.g., provider resolution)
    // Include requestId in the server log
    print(
      '[ReqID: $requestId] Unexpected error in /data/[id].dart handler: $e\n$stackTrace',
    );
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: 'Internal Server Error.',
    );
  }
}

// --- GET Handler ---
/// Handles GET requests: Retrieves a single item by its ID.
/// Includes request metadata in response.
Future<Response> _handleGet(
  RequestContext context,
  String id,
  String modelName,
  String requestId, // Receive requestId
) async {
  dynamic item; // Use dynamic
  // Repository exceptions (like NotFoundException) will propagate up.
  try {
    switch (modelName) {
      case 'headline':
        final repo = context.read<HtDataRepository<Headline>>();
        item = await repo.read(id);
      case 'category':
        final repo = context.read<HtDataRepository<Category>>();
        item = await repo.read(id);
      case 'source':
        final repo = context.read<HtDataRepository<Source>>();
        item = await repo.read(id);
      case 'country':
        final repo = context.read<HtDataRepository<Country>>();
        item = await repo.read(id);
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
      '[ReqID: $requestId] Error reading repository provider for model "$modelName" in _handleGet [id]: $e',
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
  ModelConfig modelConfig,
  String requestId, // Receive requestId
) async {
  final requestBody = await context.request.json() as Map<String, dynamic>?;
  if (requestBody == null) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Missing or invalid request body.',
    );
  }

  // Deserialize using ModelConfig's fromJson, catching TypeErrors locally
  dynamic itemToUpdate; // Use dynamic initially
  try {
    itemToUpdate = modelConfig.fromJson(requestBody);
  } on TypeError catch (e) {
    // Catch errors during deserialization (e.g., missing required fields)
    // Include requestId in the server log
    print(
      '[ReqID: $requestId] Deserialization TypeError in PUT /data/[id]: $e',
    );
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

  dynamic updatedItem; // Use dynamic
  // Repository exceptions (like NotFoundException, BadRequestException)
  // will propagate up.
  try {
    switch (modelName) {
      case 'headline':
        {
          final repo = context.read<HtDataRepository<Headline>>();
          final typedItem = itemToUpdate as Headline;
          // Validate ID match between path and body
          if (typedItem.id != id) {
            return Response(
              statusCode: HttpStatus.badRequest,
              body:
                  'Bad Request: ID in request body ("${typedItem.id}") does not match ID in path ("$id").',
            );
          }
          updatedItem = await repo.update(id, typedItem);
        }
      case 'category':
        {
          final repo = context.read<HtDataRepository<Category>>();
          final typedItem = itemToUpdate as Category;
          // Validate ID match between path and body
          if (typedItem.id != id) {
            return Response(
              statusCode: HttpStatus.badRequest,
              body:
                  'Bad Request: ID in request body ("${typedItem.id}") does not match ID in path ("$id").',
            );
          }
          updatedItem = await repo.update(id, typedItem);
        }
      case 'source':
        {
          final repo = context.read<HtDataRepository<Source>>();
          final typedItem = itemToUpdate as Source;
          // Validate ID match between path and body
          if (typedItem.id != id) {
            return Response(
              statusCode: HttpStatus.badRequest,
              body:
                  'Bad Request: ID in request body ("${typedItem.id}") does not match ID in path ("$id").',
            );
          }
          updatedItem = await repo.update(id, typedItem);
        }
      case 'country':
        {
          final repo = context.read<HtDataRepository<Country>>();
          final typedItem = itemToUpdate as Country;
          // Validate ID match between path and body
          if (typedItem.id != id) {
            return Response(
              statusCode: HttpStatus.badRequest,
              body:
                  'Bad Request: ID in request body ("${typedItem.id}") does not match ID in path ("$id").',
            );
          }
          updatedItem = await repo.update(id, typedItem);
        }
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
      '[ReqID: $requestId] Error reading repository provider for model "$modelName" in _handlePut [id]: $e',
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

  // Wrap the updated item in SuccessApiResponse with metadata
  final successResponse = SuccessApiResponse<dynamic>(
    data: updatedItem,
    metadata: metadata, // Include the created metadata
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
  String
      requestId, // Receive requestId for logging, though not used in response
) async {
  // Repository exceptions (like NotFoundException) will propagate up.
  try {
    switch (modelName) {
      case 'headline':
        await context.read<HtDataRepository<Headline>>().delete(id);
      case 'category':
        await context.read<HtDataRepository<Category>>().delete(id);
      case 'source':
        await context.read<HtDataRepository<Source>>().delete(id);
      case 'country':
        await context.read<HtDataRepository<Country>>().delete(id);
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
      '[ReqID: $requestId] Error reading repository provider for model "$modelName" in _handleDelete [id]: $e',
    );
    return Response(
      statusCode: HttpStatus.internalServerError,
      body:
          'Internal Server Error: Could not resolve repository for model "$modelName".',
    );
  }
  // Return 204 No Content for successful deletion (no body, no metadata)
  return Response(statusCode: HttpStatus.noContent);
}
