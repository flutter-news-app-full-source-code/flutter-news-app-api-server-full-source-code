import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';

/// A wrapper class to provide a fetched item into the request context.
///
/// This ensures type safety and avoids providing a raw `dynamic` object,
/// which could lead to ambiguity if other dynamic objects are in the context.
class FetchedItem<T> {
  /// Creates a wrapper for the fetched item.
  const FetchedItem(this.data);

  /// The fetched item data.
  final T data;
}

/// Middleware to check if the authenticated user is the owner of the requested
/// item.
///
/// This middleware runs *after* the `dataFetchMiddleware`, which means it can
/// safely assume that the requested item has already been fetched and is
/// available in the context.
///
/// It performs the following steps:
/// 1. Determines if an ownership check is required for the current action
///    based on the `ModelConfig`.
/// 2. If a check is required and the user is not an admin, it reads the
///    pre-fetched item from the context.
/// 3. It then compares the item's owner ID with the authenticated user's ID.
/// 4. If the IDs do not match, it throws a [ForbiddenException].
/// 5. If the check is not required or passes, it calls the next handler.
Middleware ownershipCheckMiddleware() {
  return (handler) {
    return (context) async {
      final modelConfig = context.read<ModelConfig<dynamic>>();
      final user = context.read<User>();
      final permissionService = context.read<PermissionService>();
      final method = context.request.method;

      // Determine the required permission configuration for the current method.
      ModelActionPermission permission;
      switch (method) {
        case HttpMethod.get:
          permission = modelConfig.getItemPermission;
        case HttpMethod.put:
          permission = modelConfig.putPermission;
        case HttpMethod.delete:
          permission = modelConfig.deletePermission;
        default:
          // For any other methods, no ownership check is performed.
          return handler(context);
      }

      // If no ownership check is required for this action, or if the user is
      // an admin (who bypasses ownership checks), proceed immediately.
      if (!permission.requiresOwnershipCheck ||
          permissionService.isAdmin(user)) {
        return handler(context);
      }

      // At this point, an ownership check is required for a non-admin user.

      // Ensure the model is configured to support ownership checks.
      if (modelConfig.getOwnerId == null) {
        throw const OperationFailedException(
          'Internal Server Error: Model configuration error for ownership check.',
        );
      }

      // Read the item that was pre-fetched by the dataFetchMiddleware.
      // This is guaranteed to exist because dataFetchMiddleware would have
      // thrown a NotFoundException if the item did not exist.
      final item = context.read<FetchedItem<dynamic>>().data;

      // Compare the item's owner ID with the authenticated user's ID.
      final itemOwnerId = modelConfig.getOwnerId!(item);
      if (itemOwnerId != user.id) {
        throw const ForbiddenException(
          'You do not have permission to access this item.',
        );
      }

      // If the ownership check passes, proceed to the final route handler.
      return handler(context);
    };
  };
}
