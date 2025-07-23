import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
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
/// This middleware is designed to run on item-specific routes (e.g., `/[id]`).
/// It performs the following steps:
///
/// 1.  Determines if an ownership check is required for the current action
///     (GET, PUT, DELETE) based on the `ModelConfig`.
/// 2.  If a check is required and the user is not an admin, it fetches the
///     item from the database.
/// 3.  It then compares the item's owner ID with the authenticated user's ID.
/// 4.  If the check fails, it throws a [ForbiddenException].
/// 5.  If the check passes, it provides the fetched item into the request
///     context via `context.provide<FetchedItem<dynamic>>`. This prevents the
///     downstream route handler from needing to fetch the item again.
Middleware ownershipCheckMiddleware() {
  return (handler) {
    return (context) async {
      final modelName = context.read<String>();
      final modelConfig = context.read<ModelConfig<dynamic>>();
      final user = context.read<User>();
      final permissionService = context.read<PermissionService>();
      final method = context.request.method;
      final id = context.request.uri.pathSegments.last;

      ModelActionPermission permission;
      switch (method) {
        case HttpMethod.get:
          permission = modelConfig.getItemPermission;
        case HttpMethod.put:
          permission = modelConfig.putPermission;
        case HttpMethod.delete:
          permission = modelConfig.deletePermission;
        default:
          // For other methods, no ownership check is performed here.
          return handler(context);
      }

      // If no ownership check is required or if the user is an admin,
      // proceed to the next handler without fetching the item.
      if (!permission.requiresOwnershipCheck ||
          permissionService.isAdmin(user)) {
        return handler(context);
      }

      if (modelConfig.getOwnerId == null) {
        throw const OperationFailedException(
          'Internal Server Error: Model configuration error for ownership check.',
        );
      }

      final userIdForRepoCall = user.id;
      dynamic item;

      switch (modelName) {
        case 'user':
          final repo = context.read<DataRepository<User>>();
          item = await repo.read(id: id, userId: userIdForRepoCall);
        case 'user_app_settings':
          final repo = context.read<DataRepository<UserAppSettings>>();
          item = await repo.read(id: id, userId: userIdForRepoCall);
        case 'user_content_preferences':
          final repo = context.read<DataRepository<UserContentPreferences>>();
          item = await repo.read(id: id, userId: userIdForRepoCall);
        default:
          throw OperationFailedException(
            'Ownership check not implemented for model "$modelName".',
          );
      }

      final itemOwnerId = modelConfig.getOwnerId!(item);
      if (itemOwnerId != user.id) {
        throw const ForbiddenException(
          'You do not have permission to access this item.',
        );
      }

      final updatedContext = context.provide<FetchedItem<dynamic>>(
        () => FetchedItem(item),
      );

      return handler(updatedContext);
    };
  };
}
