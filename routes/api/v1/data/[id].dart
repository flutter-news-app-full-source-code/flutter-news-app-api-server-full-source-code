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
  // Read ModelConfig for fromJson/getId (needed for PUT)
  final modelConfig = context.read<ModelConfig<dynamic>>();

  try {
    // --- GET Request ---
    if (context.request.method == HttpMethod.get) {
      Map<String, dynamic> itemJson;
      try {
        switch (modelName) {
          case 'headline':
            final repo = context.read<HtDataRepository<Headline>>();
            final item = await repo.read(id);
            // Serialize using the specific model's toJson method
            itemJson = item.toJson();
          case 'category':
            final repo = context.read<HtDataRepository<Category>>();
            final item = await repo.read(id);
            itemJson = item.toJson();
          case 'source':
            final repo = context.read<HtDataRepository<Source>>();
            final item = await repo.read(id);
            itemJson = item.toJson();
          case 'country':
            final repo = context.read<HtDataRepository<Country>>();
            final item = await repo.read(id);
            itemJson = item.toJson();
          default:
            return Response(
              statusCode: HttpStatus.internalServerError,
              body:
                  'Internal Server Error: Unsupported model type "$modelName" reached handler.',
            );
        }
      } catch (e) {
        // Catch potential provider errors during context.read
        print(
          'Error reading repository provider for model "$modelName" in GET [id]: $e',
        );
        return Response(
          statusCode: HttpStatus.internalServerError,
          body:
              'Internal Server Error: Could not resolve repository for model "$modelName".',
        );
      }
      // Return the serialized item
      return Response.json(body: itemJson);
    }

    // --- PUT Request ---
    if (context.request.method == HttpMethod.put) {
      final requestBody = await context.request.json() as Map<String, dynamic>?;
      if (requestBody == null) {
        return Response(
          statusCode: HttpStatus.badRequest,
          body: 'Missing or invalid request body.',
        );
      }

      // Deserialize using ModelConfig's fromJson
      final itemToUpdate = modelConfig.fromJson(requestBody);

      // Validate ID consistency using ModelConfig's getId
      final incomingId = modelConfig.getId(itemToUpdate);
      if (incomingId != id) {
        return Response(
          statusCode: HttpStatus.badRequest,
          body:
              'Bad Request: ID in request body ("$incomingId") does not match ID in path ("$id").',
        );
      }

      Map<String, dynamic> updatedJson;
      try {
        switch (modelName) {
          case 'headline':
            final repo = context.read<HtDataRepository<Headline>>();
            // Cast itemToUpdate to the specific type expected by the repository's update method
            final updatedItem = await repo.update(id, itemToUpdate as Headline);
            // Serialize using the specific model's toJson method
            updatedJson = updatedItem.toJson();
          case 'category':
            final repo = context.read<HtDataRepository<Category>>();
            final updatedItem = await repo.update(id, itemToUpdate as Category);
            updatedJson = updatedItem.toJson();
          case 'source':
            final repo = context.read<HtDataRepository<Source>>();
            final updatedItem = await repo.update(id, itemToUpdate as Source);
            updatedJson = updatedItem.toJson();
          case 'country':
            final repo = context.read<HtDataRepository<Country>>();
            final updatedItem = await repo.update(id, itemToUpdate as Country);
            updatedJson = updatedItem.toJson();
          default:
            return Response(
              statusCode: HttpStatus.internalServerError,
              body:
                  'Internal Server Error: Unsupported model type "$modelName" reached handler.',
            );
        }
      } catch (e) {
        // Catch potential provider errors during context.read
        print(
          'Error reading repository provider for model "$modelName" in PUT [id]: $e',
        );
        return Response(
          statusCode: HttpStatus.internalServerError,
          body:
              'Internal Server Error: Could not resolve repository for model "$modelName".',
        );
      }
      // Return the serialized updated item
      return Response.json(body: updatedJson);
    }

    // --- DELETE Request ---
    if (context.request.method == HttpMethod.delete) {
      try {
        // No serialization needed, just call delete based on type
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
            return Response(
              statusCode: HttpStatus.internalServerError,
              body:
                  'Internal Server Error: Unsupported model type "$modelName" reached handler.',
            );
        }
      } catch (e) {
        // Catch potential provider errors during context.read
        print(
          'Error reading repository provider for model "$modelName" in DELETE [id]: $e',
        );
        return Response(
          statusCode: HttpStatus.internalServerError,
          body:
              'Internal Server Error: Could not resolve repository for model "$modelName".',
        );
      }
      // Return 204 No Content for successful deletion
      return Response(statusCode: HttpStatus.noContent);
    }

    // --- Other Methods ---
    // Methods not allowed on the item endpoint
    return Response(statusCode: HttpStatus.methodNotAllowed);
  } on NotFoundException catch (e) {
    // Handle specific case where the item ID is not found
    // This should be caught by the central error handler, but added as fallback
    return Response(statusCode: HttpStatus.notFound, body: e.message);
  } on HtHttpException catch (e) {
    // Handle other known HTTP exceptions
    // These should ideally be caught by the central error handler middleware
    if (e is BadRequestException) {
      return Response(statusCode: HttpStatus.badRequest, body: e.message);
    }
    print('HtHttpException occurred in /data/[id].dart: $e');
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: 'API Error: ${e.message}',
    );
  } on FormatException catch (e) {
    // Handle potential JSON parsing/serialization errors during PUT
    print('FormatException occurred in /data/[id].dart: $e');
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Invalid data format: ${e.message}',
    );
  } catch (e, stackTrace) {
    // Catch any other unexpected errors
    print(
      'Unexpected error in /data/[id].dart handler: $e\n$stackTrace',
    );
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: 'Internal Server Error.',
    );
  }
}
