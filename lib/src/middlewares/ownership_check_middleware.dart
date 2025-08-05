import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';

/// Middleware to check if the authenticated user is the owner of the requested
/// resource.
///
/// This middleware is designed to run on item-specific routes where the last
/// path segment is the resource ID (e.g., `/users/[id]`).
///
/// It performs the following steps:
/// 1.  Checks if the authenticated user is an admin. If so, access is granted
///     immediately.
/// 2.  If the user is not an admin, it compares the authenticated user's ID
///     with the resource ID from the URL path.
/// 3.  If the IDs do not match, it throws a [ForbiddenException].
/// 4.  If the check passes, it proceeds to the next handler.
Middleware userOwnershipMiddleware() {
  return (handler) {
    return (context) {
      final user = context.read<User>();
      final permissionService = context.read<PermissionService>();
      final resourceId = context.request.uri.pathSegments.last;

      // Admins can access any user's resources.
      if (permissionService.isAdmin(user)) {
        return handler(context);
      }

      // For non-admins, the user's ID must match the resource ID in the path.
      if (user.id != resourceId) {
        throw const ForbiddenException(
          'You do not have permission to access this resource.',
        );
      }

      // If the check passes, proceed to the next handler.
      return handler(context);
    };
  };
}
