//
// ignore_for_file: lines_longer_than_80_chars, avoid_catches_without_on_clauses, avoid_catching_errors

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
      // Removed inner try-catch block to allow exceptions to propagate
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
          // This case should ideally be caught by middleware, but added for safety
          return Response(
            statusCode: HttpStatus.internalServerError,
            body:
                'Internal Server Error: Unsupported model type "$modelName" reached handler.',
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

      // Deserialize using ModelConfig's fromJson, catching TypeErrors
      dynamic itemToUpdate; // Use dynamic initially
      try {
        itemToUpdate = modelConfig.fromJson(requestBody);
      } on TypeError catch (e) {
        // Catch errors during deserialization (e.g., missing required fields)
        print('Deserialization TypeError in PUT /data/[id]: $e');
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

      // ID validation moved inside the switch block after type casting

      Map<String, dynamic> updatedJson;
      // Removed inner try-catch block to allow exceptions to propagate
      switch (modelName) {
        case 'headline':
          {
            // Added block scope
            final repo = context.read<HtDataRepository<Headline>>();
            final typedItem = itemToUpdate as Headline; // Cast to specific type
            // Validate ID consistency
            if (typedItem.id != id) {
              return Response(
                statusCode: HttpStatus.badRequest,
                body:
                    'Bad Request: ID in request body ("${typedItem.id}") does not match ID in path ("$id").',
              );
            }
            final updatedItem = await repo.update(id, typedItem);
            updatedJson = updatedItem.toJson();
          } // End block scope
        case 'category':
          {
            // Added block scope
            final repo = context.read<HtDataRepository<Category>>();
            final typedItem = itemToUpdate as Category; // Cast to specific type
            // Validate ID consistency
            if (typedItem.id != id) {
              return Response(
                statusCode: HttpStatus.badRequest,
                body:
                    'Bad Request: ID in request body ("${typedItem.id}") does not match ID in path ("$id").',
              );
            }
            final updatedItem = await repo.update(id, typedItem);
            updatedJson = updatedItem.toJson();
          } // End block scope
        case 'source':
          {
            // Added block scope
            final repo = context.read<HtDataRepository<Source>>();
            final typedItem = itemToUpdate as Source; // Cast to specific type
            // Validate ID consistency
            if (typedItem.id != id) {
              return Response(
                statusCode: HttpStatus.badRequest,
                body:
                    'Bad Request: ID in request body ("${typedItem.id}") does not match ID in path ("$id").',
              );
            }
            final updatedItem = await repo.update(id, typedItem);
            updatedJson = updatedItem.toJson();
          } // End block scope
        case 'country':
          {
            // Added block scope
            final repo = context.read<HtDataRepository<Country>>();
            final typedItem = itemToUpdate as Country; // Cast to specific type
            // Validate ID consistency
            if (typedItem.id != id) {
              return Response(
                statusCode: HttpStatus.badRequest,
                body:
                    'Bad Request: ID in request body ("${typedItem.id}") does not match ID in path ("$id").',
              );
            }
            final updatedItem = await repo.update(id, typedItem);
            updatedJson = updatedItem.toJson();
          } // End block scope
        default:
          // This case should ideally be caught by middleware, but added for safety
          return Response(
            statusCode: HttpStatus.internalServerError,
            body:
                'Internal Server Error: Unsupported model type "$modelName" reached handler.',
          );
      }
      // Return the serialized updated item
      return Response.json(body: updatedJson);
    }

    // --- DELETE Request ---
    if (context.request.method == HttpMethod.delete) {
      // Removed inner try-catch block to allow exceptions to propagate
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
          // This case should ideally be caught by middleware, but added for safety
          return Response(
            statusCode: HttpStatus.internalServerError,
            body:
                'Internal Server Error: Unsupported model type "$modelName" reached handler.',
          );
      }
      // Return 204 No Content for successful deletion
      return Response(statusCode: HttpStatus.noContent);
    }

    // --- Other Methods ---
    // Methods not allowed on the item endpoint
    return Response(statusCode: HttpStatus.methodNotAllowed);
  } on HtHttpException catch (_) {
    // Let the errorHandler middleware handle HtHttpExceptions (incl. NotFound)
    rethrow;
  } on FormatException catch (_) {
    // Let the errorHandler middleware handle FormatExceptions (e.g., from PUT body)
    rethrow;
  } catch (e, stackTrace) {
    // Handle any other unexpected errors locally (e.g., provider resolution)
    print(
      'Unexpected error in /data/[id].dart handler: $e\n$stackTrace',
    );
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: 'Internal Server Error.',
    );
  }
}
