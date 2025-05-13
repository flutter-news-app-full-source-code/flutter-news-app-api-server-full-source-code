//
// ignore_for_file: lines_longer_than_80_chars

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/middlewares/authentication_middleware.dart';
import 'package:ht_api/src/registry/model_registry.dart';

/// Middleware specific to the generic `/api/v1/data` route path.
///
/// This middleware chain performs the following in order:
/// 1.  **Authentication Check (`requireAuthentication`):** Ensures that the user
///     is authenticated. If not, it aborts the request with a 401.
/// 2.  **Model Validation & Context Provision (`_modelValidationAndProviderMiddleware`):**
///     - Validates the `model` query parameter.
///     - Looks up the `ModelConfig` from the `ModelRegistryMap`.
///     - Provides the `ModelConfig` and `modelName` into the request context
///       for downstream route handlers.
///
/// This setup ensures that data routes are protected and have the necessary
/// model-specific configuration available.

// Helper middleware for model validation and context provision.
Middleware _modelValidationAndProviderMiddleware() {
  return (handler) {
    // This 'handler' is the next handler in the chain,
    // which, in this setup, is the actual route handler from
    // index.dart or [id].dart.
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
      // Read the globally provided registry (from routes/_middleware.dart)
      final registry = context.read<ModelRegistryMap>();
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
      final updatedContext = context
          .provide<ModelConfig<dynamic>>(() => modelConfig)
          .provide<String>(() => modelName);

      // Call the next handler in the chain with the updated context
      return handler(updatedContext);
    };
  };
}

// Main middleware exported for the /api/v1/data route group.
Handler middleware(Handler handler) {
  // This 'handler' is the actual route handler from index.dart or [id].dart.
  // The .use() method applies middleware in an "onion-skin" fashion.
  // The last .use() is the outermost layer.
  // So, requireAuthentication() runs first. If it passes,
  // _modelValidationAndProviderMiddleware() runs next.
  // If that passes, the actual route handler is executed.
  return handler
      .use(_modelValidationAndProviderMiddleware())
      .use(requireAuthentication());
}
