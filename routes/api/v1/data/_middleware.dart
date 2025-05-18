import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/middlewares/authentication_middleware.dart';
import 'package:ht_api/src/middlewares/authorization_middleware.dart'; // Import authorization middleware
import 'package:ht_api/src/registry/model_registry.dart';
import 'package:ht_shared/ht_shared.dart'; // For BadRequestException

/// Middleware specific to the generic `/api/v1/data` route path.
///
/// This middleware chain performs the following in order:
/// 1.  **Authentication Check (`requireAuthentication`):** Ensures that the user
///     is authenticated. If not, it aborts the request with a 401.
/// 2.  **Model Validation & Context Provision (`_modelValidationAndProviderMiddleware`):**
///     - Validates the `model` query parameter.
///     - Looks up the `ModelConfig` from the `ModelRegistryMap`.
///     - Provides the `ModelConfig` and `modelName` into the request context
///       for downstream middleware and route handlers.
/// 3.  **Authorization Check (`authorizationMiddleware`):** Enforces role-based
///     and model-specific permissions based on the `ModelConfig` metadata.
///     If the user lacks permission, it throws a [ForbiddenException].
///
/// This setup ensures that data routes are protected, have the necessary
/// model-specific configuration available, and access is authorized before
/// reaching the final route handler.

// Helper middleware for model validation and context provision.
Middleware _modelValidationAndProviderMiddleware() {
  return (handler) {
    // This 'handler' is the next handler in the chain,
    // which, in this setup, is the authorizationMiddleware.
    return (context) async {
      // --- 1. Read and Validate `model` Parameter ---
      final modelName = context.request.uri.queryParameters['model'];
      if (modelName == null || modelName.isEmpty) {
        // Throw BadRequestException to be caught by the errorHandler
        throw const BadRequestException(
          'Missing or empty "model" query parameter.',
        );
      }

      // --- 2. Look Up Model Configuration ---
      // Read the globally provided registry (from routes/_middleware.dart)
      final registry = context.read<ModelRegistryMap>();
      final modelConfig = registry[modelName];

      // Further validation: Ensure model exists in the registry
      if (modelConfig == null) {
        // Throw BadRequestException to be caught by the errorHandler
        throw BadRequestException(
          'Invalid model type "$modelName". '
          'Supported models are: ${registry.keys.join(', ')}.',
        );
      }

      // --- 3. Provide Context Downstream ---
      final updatedContext = context
          .provide<ModelConfig<dynamic>>(() => modelConfig)
          .provide<String>(() => modelName);

      // Call the next handler in the chain (authorizationMiddleware)
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
  //    - If model validation fails, it throws a BadRequestException, caught
  //      by the global errorHandler.
  //    - If successful, it calls the next handler in the chain (authorizationMiddleware).
  //
  // 3. `authorizationMiddleware()`:
  //    - This runs if `_modelValidationAndProviderMiddleware()` passes.
  //    - It reads the `User`, `modelName`, and `ModelConfig` from the context.
  //    - It checks if the user has permission to perform the requested HTTP
  //      method on the specified model based on the `ModelConfig` metadata.
  //    - If authorization fails, it throws a ForbiddenException, caught by
  //      the global errorHandler.
  //    - If successful, it calls the next handler in the chain (the actual
  //      route handler).
  //
  // 4. Actual Route Handler (from `index.dart` or `[id].dart`):
  //    - This runs last, only if all preceding middlewares pass. It will have
  //      access to a non-null `User`, `ModelConfig`, and `modelName` from the context.
  //    - It performs the data operation and any necessary handler-level
  //      ownership checks (if flagged by `ModelActionPermission.requiresOwnershipCheck`).
  //
  return handler
      .use(authorizationMiddleware()) // Applied third (inner)
      .use(_modelValidationAndProviderMiddleware()) // Applied second
      .use(requireAuthentication()); // Applied first (outermost)
}
