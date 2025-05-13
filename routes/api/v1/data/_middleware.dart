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
  //
  // The .use() method applies middleware in an "onion-skin" fashion, where
  // the last .use() call in the chain represents the outermost middleware layer.
  // Therefore, the execution order for an incoming request is:
  //
  // 1. `requireAuthentication()`:
  //    - This runs first. It relies on `authenticationProvider()` (from the
  //      parent `/api/v1/_middleware.dart`) having already attempted to
  //      authenticate the user and provide `User?` into the context.
  //    - If `User` is null (no valid authentication), `requireAuthentication()`
  //      throws an `UnauthorizedException`, and the request is aborted (usually
  //      resulting in a 401 response via the global `errorHandler`).
  //    - If `User` is present, the request proceeds to the next middleware.
  //
  // 2. `_modelValidationAndProviderMiddleware()`:
  //    - This runs if `requireAuthentication()` passes.
  //    - It validates the `?model=` query parameter and provides the
  //      `ModelConfig` and `modelName` into the context.
  //    - If model validation fails, it returns a 400 Bad Request response directly.
  //    - If successful, it calls the next handler in the chain.
  //
  // 3. Actual Route Handler (from `index.dart` or `[id].dart`):
  //    - This runs last, only if both preceding middlewares pass. It will have
  //      access to a non-null `User`, `ModelConfig`, and `modelName` from the context.
  //
  return handler
      .use(_modelValidationAndProviderMiddleware()) // Applied second (inner)
      .use(requireAuthentication()); // Applied first (outermost)
}
