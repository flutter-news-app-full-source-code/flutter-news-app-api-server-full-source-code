import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/rate_limiter_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';

// Helper middleware for applying rate limiting to the data routes.
Middleware _dataRateLimiterMiddleware() {
  return (handler) {
    return (context) async {
      // Made async because ipKeyExtractor is async
      final user = context.read<User?>(); // Read nullable User
      final permissionService = context.read<PermissionService>();

      // Users with the bypass permission are not rate-limited.
      if (user != null &&
          permissionService.hasPermission(
            user,
            Permissions.rateLimitingBypass,
          )) {
        return handler(context);
      }

      String? key;
      // If user is null, it means it's a public route (as per _conditionalAuthenticationMiddleware)
      // In this case, use IP-based rate limiting.
      if (user == null) {
        key = await ipKeyExtractor(context);
      } else {
        // Authenticated user: use user ID for rate limiting.
        key = user.id;
      }

      // If a key cannot be extracted (e.g., no IP), bypass rate limiter.
      if (key == null || key.isEmpty) {
        return handler(context);
      }

      // For all other users (or IPs for public routes), apply the configured rate limit.
      final rateLimitHandler = rateLimiter(
        limit: EnvironmentConfig.rateLimitDataApiLimit,
        window: EnvironmentConfig.rateLimitDataApiWindow,
        keyExtractor: (context) async => key, // Use the determined key
      )(handler);

      return rateLimitHandler(context);
    };
  };
}

/// Helper middleware for model validation and context provision.
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

/// Helper middleware to conditionally apply authentication based on
/// `ModelConfig`.
///
/// This middleware checks the `requiresAuthentication` flag on the
/// `ModelActionPermission` for the current model and HTTP method.
/// If authentication is required, it calls `requireAuthentication()`.
/// If not, it simply passes the request through, allowing public access.
Middleware _conditionalAuthenticationMiddleware() {
  return (handler) {
    return (context) {
      final modelConfig = context.read<ModelConfig<dynamic>>();
      final method = context.request.method;

      ModelActionPermission requiredPermissionConfig;
      switch (method) {
        case HttpMethod.get:
          // Differentiate GET based on whether it's a collection or item request
          final isCollectionRequest =
              context.request.uri.path == '/api/v1/data';
          if (isCollectionRequest) {
            requiredPermissionConfig = modelConfig.getCollectionPermission;
          } else {
            requiredPermissionConfig = modelConfig.getItemPermission;
          }
        case HttpMethod.post:
          requiredPermissionConfig = modelConfig.postPermission;
        case HttpMethod.put:
          requiredPermissionConfig = modelConfig.putPermission;
        case HttpMethod.delete:
          requiredPermissionConfig = modelConfig.deletePermission;
        default:
          // For unsupported methods, assume authentication is required
          // or let subsequent middleware/route handler deal with it.
          requiredPermissionConfig = const ModelActionPermission(
            type: RequiredPermissionType.unsupported,
            requiresAuthentication: true,
          );
      }

      if (requiredPermissionConfig.requiresAuthentication) {
        // If authentication is required, apply the requireAuthentication middleware.
        return requireAuthentication()(handler)(context);
      } else {
        // If authentication is not required, simply pass the request through.
        // Also provide a null User to the context for consistency,
        // so downstream middleware can always read User?
        return handler(context.provide<User?>(() => null));
      }
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
  // 1. `_modelValidationAndProviderMiddleware()`:
  //    - This runs first. It validates the `?model=` query parameter and
  //      provides the `ModelConfig` and `modelName` into the context.
  //    - If model validation fails, it throws a `BadRequestException`.
  //
  // 2. `_conditionalAuthenticationMiddleware()`:
  //    - This runs second. It dynamically decides whether to apply
  //      `requireAuthentication()` based on the `ModelConfig` for the
  //      requested model and HTTP method.
  //    - If authentication is required and the user is not authenticated,
  //      it throws an `UnauthorizedException`.
  //    - If authentication is NOT required, it provides `User?` as `null`
  //      to the context.
  //
  // 3. `_dataRateLimiterMiddleware()`:
  //    - This runs third. It checks if the user has a bypass permission.
  //      If not, it applies the configured rate limit based on the user's ID
  //      (if authenticated) or the client's IP address (if unauthenticated).
  //    - If the limit is exceeded, it throws a `ForbiddenException`.
  //
  // 4. `authorizationMiddleware()`:
  //    - This runs fourth. It reads the `User` (which is guaranteed to be
  //      non-null if authentication was required and passed) or `User?` (if
  //      authentication was not required), `modelName`, and `ModelConfig`
  //      from the context.
  //    - It checks if the user has permission to perform the requested HTTP
  //      method on the specified model based on the `ModelConfig` metadata.
  //    - If authorization fails, it throws a ForbiddenException, caught by
  //      the global errorHandler.
  //    - If successful, it calls the next handler in the chain (the actual
  //      route handler).
  //
  // 5. Actual Route Handler (from `index.dart` or `[id].dart`):
  //    - This runs last, only if all preceding middlewares pass. It will have
  //      access to a non-null `User` (if authenticated), `ModelConfig`, and
  //      `modelName` from the context.
  //    - It performs the data operation and any necessary handler-level
  //      ownership checks (if flagged by `ModelActionPermission.requiresOwnershipCheck`).
  //
  return handler
      .use(authorizationMiddleware()) // Applied fourth (inner-most)
      .use(_dataRateLimiterMiddleware()) // Applied third
      .use(_conditionalAuthenticationMiddleware()) // Applied second
      .use(
        _modelValidationAndProviderMiddleware(),
      ); // Applied first (outermost)
}
