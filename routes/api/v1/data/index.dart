//
// ignore_for_file: lines_longer_than_80_chars, avoid_catches_without_on_clauses

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/registry/model_registry.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_http_client/ht_http_client.dart'; // Import exceptions
import 'package:ht_shared/ht_shared.dart'; // Import models

/// Handles requests for the /api/v1/data collection endpoint.
/// Supports:
/// - GET: Retrieves all items for the specified model (with optional query/pagination).
/// - POST: Creates a new item for the specified model.
Future<Response> onRequest(RequestContext context) async {
  // Read dependencies provided by middleware
  final modelName = context.read<String>();
  // Read ModelConfig for fromJson (needed for POST)
  final modelConfig = context.read<ModelConfig<dynamic>>();

  try {
    // --- GET Request ---
    if (context.request.method == HttpMethod.get) {
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
      List<Map<String, dynamic>> jsonList;
      try {
        switch (modelName) {
          case 'headline':
            final repo = context.read<HtDataRepository<Headline>>();
            final results = specificQuery.isNotEmpty
                ? await repo.readAllByQuery(
                    specificQuery,
                    startAfterId: startAfterId,
                    limit: limit,
                  )
                : await repo.readAll(startAfterId: startAfterId, limit: limit);
            // Serialize using the specific model's toJson method
            jsonList = results.map((item) => item.toJson()).toList();
          case 'category':
            final repo = context.read<HtDataRepository<Category>>();
            final results = specificQuery.isNotEmpty
                ? await repo.readAllByQuery(
                    specificQuery,
                    startAfterId: startAfterId,
                    limit: limit,
                  )
                : await repo.readAll(startAfterId: startAfterId, limit: limit);
            // Serialize using the specific model's toJson method
            jsonList = results.map((item) => item.toJson()).toList();
          case 'source':
            final repo = context.read<HtDataRepository<Source>>();
            final results = specificQuery.isNotEmpty
                ? await repo.readAllByQuery(
                    specificQuery,
                    startAfterId: startAfterId,
                    limit: limit,
                  )
                : await repo.readAll(startAfterId: startAfterId, limit: limit);
            // Serialize using the specific model's toJson method
            jsonList = results.map((item) => item.toJson()).toList();
          case 'country':
            final repo = context.read<HtDataRepository<Country>>();
            final results = specificQuery.isNotEmpty
                ? await repo.readAllByQuery(
                    specificQuery,
                    startAfterId: startAfterId,
                    limit: limit,
                  )
                : await repo.readAll(startAfterId: startAfterId, limit: limit);
            // Serialize using the specific model's toJson method
            jsonList = results.map((item) => item.toJson()).toList();
          default:
            // This case should be caught by middleware, but added for safety
            return Response(
              statusCode: HttpStatus.internalServerError,
              body:
                  'Internal Server Error: Unsupported model type "$modelName" reached handler.',
            );
        }
      } catch (e) {
        // Catch potential provider errors during context.read
        print(
          'Error reading repository provider for model "$modelName" in GET: $e',
        );
        return Response(
          statusCode: HttpStatus.internalServerError,
          body:
              'Internal Server Error: Could not resolve repository for model "$modelName".',
        );
      }
      // Return the serialized list
      return Response.json(body: jsonList);
    }

    // --- POST Request ---
    if (context.request.method == HttpMethod.post) {
      final requestBody = await context.request.json() as Map<String, dynamic>?;
      if (requestBody == null) {
        return Response(
          statusCode: HttpStatus.badRequest,
          body: 'Missing or invalid request body.',
        );
      }

      // Deserialize using ModelConfig's fromJson
      final newItem = modelConfig.fromJson(requestBody);

      // Process based on model type
      Map<String, dynamic> createdJson;
      try {
        switch (modelName) {
          case 'headline':
            final repo = context.read<HtDataRepository<Headline>>();
            // Cast newItem to the specific type expected by the repository's create method
            final createdItem = await repo.create(newItem as Headline);
            // Serialize using the specific model's toJson method
            createdJson = createdItem.toJson();
          case 'category':
            final repo = context.read<HtDataRepository<Category>>();
            final createdItem = await repo.create(newItem as Category);
            createdJson = createdItem.toJson();
          case 'source':
            final repo = context.read<HtDataRepository<Source>>();
            final createdItem = await repo.create(newItem as Source);
            createdJson = createdItem.toJson();
          case 'country':
            final repo = context.read<HtDataRepository<Country>>();
            final createdItem = await repo.create(newItem as Country);
            createdJson = createdItem.toJson();
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
          'Error reading repository provider for model "$modelName" in POST: $e',
        );
        return Response(
          statusCode: HttpStatus.internalServerError,
          body:
              'Internal Server Error: Could not resolve repository for model "$modelName".',
        );
      }
      // Return the serialized created item
      return Response.json(statusCode: HttpStatus.created, body: createdJson);
    }

    // --- Other Methods ---
    // Methods not allowed on the collection endpoint
    return Response(statusCode: HttpStatus.methodNotAllowed);
  } on HtHttpException catch (e) {
    // Handle known HTTP exceptions from the repository/client layer
    // These should ideally be caught by the central error handler middleware,
    // but handling here provides a fallback.
    if (e is BadRequestException) {
      return Response(statusCode: HttpStatus.badRequest, body: e.message);
    }
    print('HtHttpException occurred in /data/index.dart: $e'); // Log the error
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: 'API Error: ${e.message}',
    );
  } on FormatException catch (e) {
    // Handle potential JSON parsing/serialization errors during POST
    print('FormatException occurred in /data/index.dart: $e'); // Log the error
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Invalid data format: ${e.message}',
    );
  } catch (e, stackTrace) {
    // Catch any other unexpected errors
    print(
      'Unexpected error in /data/index.dart handler: $e\n$stackTrace',
    ); // Log the error and stack trace
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: 'Internal Server Error.',
    );
  }
}
