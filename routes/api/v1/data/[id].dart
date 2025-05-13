//
// ignore_for_file: lines_longer_than_80_chars, no_default_cases, avoid_catches_without_on_clauses, avoid_catching_errors

import 'dart:io';

// --- Error Handling Strategy ---
// Route-specific handlers (_handleGet, _handlePut, _handleDelete, etc.) should
// generally allow HtHttpExceptions (like NotFoundException, BadRequestException)
// and FormatExceptions thrown by lower layers (Repositories, Clients, JSON parsing)
// to propagate upwards.
//
// These specific exceptions are caught and re-thrown by the main `onRequest`
// handler in this file.
//
// The centralized `errorHandler` middleware (defined in lib/src/middlewares/)
// is responsible for catching these re-thrown exceptions and mapping them to
// appropriate, standardized JSON error responses (e.g., 400, 404, 500).
//
// Local try-catch blocks within specific _handle* methods should be reserved
// for handling errors that require immediate, localized responses (like the
// TypeError during deserialization in _handlePut) or for logging specific
// context before allowing propagation.

import 'package:dart_frog/dart_frog.dart';
// Import RequestId from the middleware file where it's defined
import 'package:ht_api/src/registry/model_registry.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
// Import exceptions
// Import models, SuccessApiResponse, ResponseMetadata
import 'package:ht_shared/ht_shared.dart';

import '../../../_middleware.dart';

/// Handles requests for the /api/v1/data/[id] endpoint.
/// Dispatches requests to specific handlers based on the HTTP method.
Future<Response> onRequest(RequestContext context, String id) async {
  // Read dependencies provided by middleware
  final modelName = context.read<String>();
  final modelConfig = context.read<ModelConfig<dynamic>>();
  final requestId = context.read<RequestId>().id;
  // Since requireAuthentication is used, User is guaranteed to be non-null.
  final authenticatedUser = context.read<User>();

  try {
    switch (context.request.method) {
      case HttpMethod.get:
        return await _handleGet(
          context,
          id,
          modelName,
          modelConfig, // Pass modelConfig
          authenticatedUser,
          requestId,
        );
      case HttpMethod.put:
        return await _handlePut(
          context,
          id,
          modelName,
          modelConfig,
          authenticatedUser,
          requestId,
        );
      case HttpMethod.delete:
        return await _handleDelete(
          context,
          id,
          modelName,
          modelConfig, // Pass modelConfig
          authenticatedUser,
          requestId,
        );
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
  ModelConfig<dynamic> modelConfig, // Receive modelConfig
  User authenticatedUser, // Receive authenticatedUser
  String requestId,
) async {
  dynamic item; // Use dynamic

  String? userIdForRepoCall;
  if (modelConfig.ownership == ModelOwnership.userOwned) {
    userIdForRepoCall = authenticatedUser.id;
  } else {
    userIdForRepoCall = null;
  }

  // Repository exceptions (like NotFoundException) will propagate up.
  try {
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
  ModelConfig<dynamic> modelConfig,
  User authenticatedUser, // Receive authenticatedUser
  String requestId,
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

  String? userIdForRepoCall;
  if (modelConfig.ownership == ModelOwnership.userOwned) {
    userIdForRepoCall = authenticatedUser.id;
  } else {
    // For global models, update might imply admin rights.
    // For now, pass null, assuming repo handles global updates or has other checks.
    userIdForRepoCall = null;
  }

  // Repository exceptions (like NotFoundException, BadRequestException)
  // will propagate up.
  try {
    switch (modelName) {
      case 'headline':
        {
          final repo = context.read<HtDataRepository<Headline>>();
          final typedItem = itemToUpdate as Headline;
          if (typedItem.id != id) {
            return Response(
              statusCode: HttpStatus.badRequest,
              body:
                  'Bad Request: ID in request body ("${typedItem.id}") does not match ID in path ("$id").',
            );
          }
          updatedItem = await repo.update(
            id: id,
            item: typedItem,
            userId: userIdForRepoCall,
          );
        }
      case 'category':
        {
          final repo = context.read<HtDataRepository<Category>>();
          final typedItem = itemToUpdate as Category;
          if (typedItem.id != id) {
            return Response(
              statusCode: HttpStatus.badRequest,
              body:
                  'Bad Request: ID in request body ("${typedItem.id}") does not match ID in path ("$id").',
            );
          }
          updatedItem = await repo.update(
            id: id,
            item: typedItem,
            userId: userIdForRepoCall,
          );
        }
      case 'source':
        {
          final repo = context.read<HtDataRepository<Source>>();
          final typedItem = itemToUpdate as Source;
          if (typedItem.id != id) {
            return Response(
              statusCode: HttpStatus.badRequest,
              body:
                  'Bad Request: ID in request body ("${typedItem.id}") does not match ID in path ("$id").',
            );
          }
          updatedItem = await repo.update(
            id: id,
            item: typedItem,
            userId: userIdForRepoCall,
          );
        }
      case 'country':
        {
          final repo = context.read<HtDataRepository<Country>>();
          final typedItem = itemToUpdate as Country;
          if (typedItem.id != id) {
            return Response(
              statusCode: HttpStatus.badRequest,
              body:
                  'Bad Request: ID in request body ("${typedItem.id}") does not match ID in path ("$id").',
            );
          }
          updatedItem = await repo.update(
            id: id,
            item: typedItem,
            userId: userIdForRepoCall,
          );
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
  ModelConfig<dynamic> modelConfig, // Receive modelConfig
  User authenticatedUser, // Receive authenticatedUser
  String requestId,
) async {
  String? userIdForRepoCall;
  if (modelConfig.ownership == ModelOwnership.userOwned) {
    userIdForRepoCall = authenticatedUser.id;
  } else {
    // For global models, delete might imply admin rights.
    // For now, pass null.
    userIdForRepoCall = null;
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
    default:
      // This case should ideally be caught by the data/_middleware.dart,
      // but added for safety. Consider logging this unexpected state.
      print(
        '[ReqID: $requestId] Error: Unsupported model type "$modelName" reached _handleDelete.',
      );
      return Response(
        statusCode: HttpStatus.internalServerError,
        body:
            'Internal Server Error: Unsupported model type "$modelName" reached handler.',
      );
  }

  // Return 204 No Content for successful deletion (no body, no metadata)
  return Response(statusCode: HttpStatus.noContent);
}
