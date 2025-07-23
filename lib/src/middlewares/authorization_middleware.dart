import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';
import 'package:logging/logging.dart';

final _log = Logger('AuthorizationMiddleware');

/// {@template authorization_middleware}
/// Middleware to enforce role-based permissions and model-specific access rules.
///
/// This middleware reads the authenticated [User], the requested `modelName`,
/// the `HttpMethod`, and the `ModelConfig` from the request context. It then
/// determines the required permission based on the `ModelConfig` metadata for
/// the specific HTTP method and checks if the authenticated user has that
/// permission using the [PermissionService].
///
/// If the user does not have the required permission, it throws a
/// [ForbiddenException], which should be caught by the 'errorHandler' middleware.
///
/// This middleware runs *after* authentication and model validation.
/// It does NOT perform instance-level ownership checks; those are handled
/// by the route handlers (`index.dart`, `[id].dart`) if required by the
/// `ModelActionPermission.requiresOwnershipCheck` flag.
/// {@endtemplate}
Middleware authorizationMiddleware() {
  return (handler) {
    return (context) async {
      // Read dependencies from the context.
      // User is guaranteed non-null by requireAuthentication() middleware.
      final user = context.read<User>();
      final permissionService = context.read<PermissionService>();
      final modelName = context.read<String>(); // Provided by data/_middleware
      final modelConfig = context
          .read<ModelConfig<dynamic>>(); // Provided by data/_middleware
      final method = context.request.method;

      // Determine if the request is for the collection or an item
      // The collection path is /api/v1/data
      // Item paths are /api/v1/data/[id]
      final isCollectionRequest = context.request.uri.path == '/api/v1/data';

      // Determine the required permission configuration based on the HTTP method
      ModelActionPermission requiredPermissionConfig;
      switch (method) {
        case HttpMethod.get:
          // Differentiate GET based on whether it's a collection or item request
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
          // Should ideally be caught earlier by Dart Frog's routing,
          // but as a safeguard, deny unsupported methods.
          throw const ForbiddenException(
            'Method not supported for this resource.',
          );
      }

      // Perform the permission check based on the configuration type
      switch (requiredPermissionConfig.type) {
        case RequiredPermissionType.none:
          // No specific permission required (beyond authentication if applicable)
          // This case is primarily for documentation/completeness if a route
          // group didn't require authentication, but the /data route does.
          // For the /data route, 'none' effectively means 'authenticated users allowed'.
          break;
        case RequiredPermissionType.adminOnly:
          // Requires the user to be an admin
          if (!permissionService.isAdmin(user)) {
            throw const ForbiddenException(
              'Only administrators can perform this action.',
            );
          }
        case RequiredPermissionType.specificPermission:
          // Requires a specific permission string
          final permission = requiredPermissionConfig.permission;
          if (permission == null) {
            // This indicates a configuration error in ModelRegistry
            _log.severe(
              'Configuration Error: specificPermission type requires a '
              'permission string for model "$modelName", method "$method".',
            );
            throw const OperationFailedException(
              'Internal Server Error: Authorization configuration error.',
            );
          }
          if (!permissionService.hasPermission(user, permission)) {
            throw const ForbiddenException(
              'You do not have permission to perform this action.',
            );
          }
        case RequiredPermissionType.unsupported:
          // This action is explicitly marked as not supported via this generic route.
          // Return Method Not Allowed.
          _log.warning(
            'Action for model "$modelName", method "$method" is marked as '
            'unsupported via generic route.',
          );
          // Throw ForbiddenException to be caught by the errorHandler
          throw ForbiddenException(
            'Method "$method" is not supported for model "$modelName" '
            'via this generic data endpoint.',
          );
      }

      // If all checks pass, proceed to the next handler in the chain.
      // Instance-level ownership checks (if requiredPermissionConfig.requiresOwnershipCheck is true)
      // are handled by the route handlers themselves.
      return handler(context);
    };
  };
}
