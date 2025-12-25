import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/role_permissions.dart';

/// {@template permission_service}
/// Service responsible for checking if a user has a specific permission.
///
/// This service uses the predefined [rolePermissions] map to determine a user's
/// access rights based on their `role` and `tier`. It also includes an explicit
/// check for the `admin` role, granting them all permissions.
/// {@endtemplate}
class PermissionService {
  /// {@macro permission_service}
  const PermissionService();

  /// Checks if the given [user] has the specified [permission].
  ///
  /// Returns `true` if the user's combined roles grant the permission, or if
  /// the user is an administrator. Returns `false` otherwise.
  ///
  /// - [user]: The authenticated user.
  /// - [permission]: The permission string to check (e.g., `headline.read`).
  bool hasPermission(User user, String permission) {
    // Administrators implicitly have all permissions.
    if (isAdmin(user)) {
      return true;
    }

    // Get the permission set for the user's role.
    final rolePerms = rolePermissions[user.role] ?? const <String>{};
    final tierPerms = rolePermissions[user.tier] ?? const <String>{};

    // Check if the combined set contains the required permission.
    return rolePerms.contains(permission) || tierPerms.contains(permission);
  }

  /// Checks if the given [user] has the `admin` role.
  ///
  /// This is a convenience method for checks that are strictly limited
  /// to administrators, bypassing the permission map.
  ///
  /// - [user]: The authenticated user.
  bool isAdmin(User user) {
    return user.role == UserRole.admin;
  }
}
