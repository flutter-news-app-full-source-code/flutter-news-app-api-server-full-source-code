//
// ignore_for_file: lines_longer_than_80_chars

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/registry/model_registry.dart';

/// Middleware specific to the generic `/api/v1/data` route path.
///
/// This middleware is crucial for the functioning of the generic data endpoint.
/// Its primary responsibilities are:
///
/// 1.  **Read and Validate `model` Parameter:** Extracts the `model` query
///     parameter from the incoming request URL (e.g., `?model=headline`).
///     It ensures this parameter exists and corresponds to a valid key
///     within the globally provided [ModelRegistryMap]. If validation fails,
///     it immediately returns a 400 Bad Request response, preventing the
///     request from reaching the actual route handlers (`index.dart`, `[id].dart`).
///
/// 2.  **Look Up Model Configuration:** Reads the globally provided
///     [ModelRegistryMap] (injected by `routes/_middleware.dart`) and uses the
///     validated `modelName` to find the corresponding [ModelConfig] instance.
///     This config contains type-specific functions (like `fromJson`) needed
///     by the downstream handlers.
///
/// 3.  **Provide Context Downstream:** Injects two crucial pieces of information
///     into the request context for the route handlers (`index.dart`, `[id].dart`)
///     to use:
///     - The specific `ModelConfig<dynamic>` for the requested model.
///     - The validated `modelName` as a `String`.
///
/// This allows the route handlers under `/api/v1/data/` to operate generically,
/// using the provided `modelName` to select the correct repository (which are
/// also provided globally) and the `ModelConfig` for type-specific operations
/// like deserializing request bodies.
///
/// If validation fails (missing/invalid model parameter), it returns a 400 Bad Request response immediately.
Handler middleware(Handler handler) {
  return (context) async {
    // --- 1. Read and Validate `model` Parameter ---
    final modelName = context.request.uri.queryParameters['model'];
    if (modelName == null || modelName.isEmpty) {
      return Response(
        statusCode: 400,
        body: 'Bad Request: Missing or empty "model" query parameter.',
      );
    }

    // --- 2. Look Up Model Configuration ---
    // Read the globally provided registry
    final registry = context.read<ModelRegistryMap>();
    // Look up the config for the validated model name
    final modelConfig = registry[modelName];

    // Further validation: Ensure model exists in the registry
    if (modelConfig == null) {
      return Response(
        statusCode: 400,
        body: 'Bad Request: Invalid model type "$modelName". '
            'Supported models are: ${registry.keys.join(', ')}.',
      );
    }

    // --- 3. Provide Context Downstream ---
    // Provide the specific ModelConfig and the validated modelName string
    // for the route handlers (`index.dart`, `[id].dart`) to use.
    final updatedContext = context
        .provide<ModelConfig<dynamic>>(() => modelConfig) // Provide the config
        .provide<String>(() => modelName); // Provide the validated model name

    // Call the next handler in the chain with the updated context
    return handler(updatedContext);
  };
}
