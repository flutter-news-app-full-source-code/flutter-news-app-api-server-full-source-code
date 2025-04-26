//
// ignore_for_file: lines_longer_than_80_chars

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/registry/model_registry.dart'; // Adjust import if needed

/// Middleware for the /api/v1/data route.
///
/// Responsibilities:
/// 1. Reads the 'model' query parameter from the request.
/// 2. Validates the 'model' parameter (must exist and be a key in the modelRegistry).
/// 3. Reads the globally provided [ModelRegistryMap].
/// 4. Looks up the corresponding [ModelConfig] for the requested model.
/// 5. Provides the specific [ModelConfig<dynamic>] for the model downstream.
/// 6. Provides the validated model name string downstream.
///
/// If validation fails (missing/invalid model parameter), it returns a 400 Bad Request response immediately.
Handler middleware(Handler handler) {
  return (context) async {
    // 1. Read the 'model' query parameter
    final modelName = context.request.uri.queryParameters['model'];

    // 2. Validate the 'model' parameter
    if (modelName == null || modelName.isEmpty) {
      return Response(
        statusCode: 400,
        body: 'Bad Request: Missing or empty "model" query parameter.',
      );
    }

    // 3. Read the globally provided ModelRegistryMap
    // Assumes modelRegistryProvider is used in a higher-level middleware (e.g., routes/_middleware.dart)
    final registry = context.read<ModelRegistryMap>();

    // 4. Look up the ModelConfig
    final modelConfig = registry[modelName];

    // 2. (cont.) Validate model existence in registry
    if (modelConfig == null) {
      return Response(
        statusCode: 400,
        body: 'Bad Request: Invalid model type "$modelName". '
            'Supported models are: ${registry.keys.join(', ')}.',
      );
    }

    // 5. & 6. Provide the ModelConfig and modelName downstream
    // We provide ModelConfig<dynamic> because the specific type T isn't known here.
    // The route handler will use this config along with the correct repository
    // instance (which should also be provided globally).
    final updatedContext = context
        .provide<ModelConfig<dynamic>>(() => modelConfig)
        .provide<String>(() => modelName); // Provide the validated model name

    // Call the next handler in the chain
    return handler(updatedContext);
  };
}
