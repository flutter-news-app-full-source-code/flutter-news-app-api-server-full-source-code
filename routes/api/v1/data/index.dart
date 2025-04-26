//
// ignore_for_file: lines_longer_than_80_chars, avoid_catches_without_on_clauses

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/registry/model_registry.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_http_client/ht_http_client.dart'; // Import exceptions
import 'package:ht_shared/ht_shared.dart'; // Import models if needed for casting

/// Handles requests for the /api/v1/data collection endpoint.
/// Supports:
/// - GET: Retrieves all items for the specified model (with optional query/pagination).
/// - POST: Creates a new item for the specified model.
Future<Response> onRequest(RequestContext context) async {
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
        // This should technically be caught by the middleware, but added for safety.
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
        // Read query parameters for pagination/filtering
        final queryParams = context.request.uri.queryParameters;
        final startAfterId = queryParams['startAfterId'];
        final limitParam = queryParams['limit'];
        final limit = limitParam != null ? int.tryParse(limitParam) : null;

        // Extract other query params for readAllByQuery, excluding pagination/model
        final specificQuery = Map<String, dynamic>.from(queryParams)
          ..remove('model')
          ..remove('startAfterId')
          ..remove('limit');

        List<dynamic> results;
        if (specificQuery.isNotEmpty) {
          // Use readAllByQuery if specific filters are present
          results = await repository.readAllByQuery(
            specificQuery,
            startAfterId: startAfterId,
            limit: limit,
          );
        } else {
          // Otherwise, use readAll
          results = await repository.readAll(
            startAfterId: startAfterId,
            limit: limit,
          );
        }
        // Serialize the list using the model-specific toJson from ModelConfig
        final jsonList = results.map(modelConfig.toJson).toList();
        return Response.json(body: jsonList);

      case HttpMethod.post:
        final requestBody =
            await context.request.json() as Map<String, dynamic>?;
        if (requestBody == null) {
          return Response(
            statusCode: HttpStatus.badRequest,
            body: 'Missing or invalid request body.',
          );
        }
        // Deserialize using the model-specific fromJson from ModelConfig
        final newItem = modelConfig.fromJson(requestBody);
        final createdItem = await repository.create(newItem);
        // Serialize the response using the model-specific toJson
        return Response.json(
          statusCode: HttpStatus.created,
          body: modelConfig.toJson(createdItem),
        );

      // Methods not allowed on the collection endpoint
      case HttpMethod.put:
      case HttpMethod.delete:
      case HttpMethod.patch:
      case HttpMethod.head:
      case HttpMethod.options:
        return Response(statusCode: HttpStatus.methodNotAllowed);
    }
  } on HtHttpException catch (e) {
    // Handle known HTTP exceptions from the repository/client layer
    // You might want to map these to specific status codes
    // This requires a helper function or using your existing error handler middleware
    if (e is BadRequestException) {
      return Response(statusCode: HttpStatus.badRequest, body: e.message);
    }
    // Add other specific exception mappings (NotFound, Unauthorized, etc.) if needed
    print('HtHttpException occurred: $e'); // Log the error
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: 'API Error: ${e.message}',
    );
  } on FormatException catch (e) {
    // Handle potential JSON parsing/serialization errors
    print('FormatException occurred: $e'); // Log the error
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Invalid data format: ${e.message}',
    );
  } catch (e, stackTrace) {
    // Catch any other unexpected errors
    print(
      'Unexpected error in /data handler: $e\n$stackTrace',
    ); // Log the error and stack trace
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: 'Internal Server Error.',
    );
  }
}
