//
// ignore_for_file: lines_longer_than_80_chars, avoid_catches_without_on_clauses

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/registry/model_registry.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_http_client/ht_http_client.dart'; // Import exceptions
import 'package:ht_shared/ht_shared.dart'; // Import models

/// Handles requests for the /api/v1/data/[id] endpoint.
/// Supports:
/// - GET: Retrieves a single item by its ID for the specified model.
/// - PUT: Updates an existing item by its ID for the specified model.
/// - DELETE: Deletes an item by its ID for the specified model.
Future<Response> onRequest(RequestContext context, String id) async {
  // Read dependencies provided by middleware
  final modelName = context.read<String>();
  final modelConfig = context.read<ModelConfig<dynamic>>();

  // Determine which repository to use based on the model name
  // Assumes repositories are provided globally (e.g., in routes/_middleware.dart)
  HtDataRepository<dynamic> repository;
  try {
    switch (modelName) {
      case 'headline':
        repository = context.read<HtDataRepository<Headline>>();
      case 'category':
        repository = context.read<HtDataRepository<Category>>();
      case 'source':
        repository = context.read<HtDataRepository<Source>>();
      case 'country': // Added case for Country
        repository = context.read<HtDataRepository<Country>>();
      default:
        // This should technically be caught by the middleware,
        // but added for safety.
        return Response(
          statusCode: HttpStatus.internalServerError,
          body:
              'Internal Server Error: Unsupported model type "$modelName" reached handler.',
        );
    }
  } catch (e) {
    // Catch potential provider errors if a repository wasn't provided correctly
    print('Error reading repository provider for model "$modelName": $e');
    return Response(
      statusCode: HttpStatus.internalServerError,
      body:
          'Internal Server Error: Could not resolve repository for model "$modelName".',
    );
  }

  try {
    switch (context.request.method) {
      case HttpMethod.get:
        final item = await repository.read(id);
        // Serialize using the model-specific toJson from ModelConfig
        return Response.json(body: modelConfig.toJson(item));

      case HttpMethod.put:
        final requestBody =
            await context.request.json() as Map<String, dynamic>?;
        if (requestBody == null) {
          return Response(
            statusCode: HttpStatus.badRequest,
            body: 'Missing or invalid request body.',
          );
        }
        // Deserialize using the model-specific fromJson from ModelConfig
        final itemToUpdate = modelConfig.fromJson(requestBody);

        // Optional: Validate ID consistency if needed (depends on requirements)
        final incomingId = modelConfig.getId(itemToUpdate);
        if (incomingId != id) {
          return Response(
            statusCode: HttpStatus.badRequest,
            body:
                'Bad Request: ID in request body ("$incomingId") does not match ID in path ("$id").',
          );
        }

        final updatedItem = await repository.update(id, itemToUpdate);
        // Serialize the response using the model-specific toJson
        return Response.json(body: modelConfig.toJson(updatedItem));

      case HttpMethod.delete:
        await repository.delete(id);
        // Return 204 No Content for successful deletion
        return Response(statusCode: HttpStatus.noContent);

      // Methods not allowed on the item endpoint
      case HttpMethod.post: // POST is for collection endpoint
      case HttpMethod
            .patch: // PATCH could be added if partial updates are needed
      case HttpMethod.head:
      case HttpMethod.options:
        return Response(statusCode: HttpStatus.methodNotAllowed);
    }
  } on NotFoundException catch (e) {
    // Handle specific case where the item ID is not found
    return Response(statusCode: HttpStatus.notFound, body: e.message);
  } on HtHttpException catch (e) {
    // Handle other known HTTP exceptions
    if (e is BadRequestException) {
      return Response(statusCode: HttpStatus.badRequest, body: e.message);
    }
    print('HtHttpException occurred: $e');
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: 'API Error: ${e.message}',
    );
  } on FormatException catch (e) {
    // Handle potential JSON parsing/serialization errors during PUT
    print('FormatException occurred: $e');
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Invalid data format: ${e.message}',
    );
  } catch (e, stackTrace) {
    // Catch any other unexpected errors
    print('Unexpected error in /data/[id] handler: $e\n$stackTrace');
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: 'Internal Server Error.',
    );
  }
}
