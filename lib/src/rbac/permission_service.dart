import 'package:ht_api/src/rbac/role_permissions.dart';
import 'package:ht_shared/ht_shared.dart';

/// {@template permission_service}
/// Service responsible for checking if a user has a specific permission.
///
/// This service uses the predefined [rolePermissions] map to determine
/// a user's access rights based on their [UserRole]. It also includes
/// an explicit check for the [UserRole.admin], granting them all permissions.
/// {@endtemplate}
class PermissionService {
  /// {@macro permission_service}
  const PermissionService();

  /// Checks if the given [user] has the specified [permission].
  ///
  /// Returns `true` if the user's role grants the permission, or if the user
  /// is an administrator. Returns `false` otherwise.
  ///
  /// - [user]: The authenticated user.
  /// - [permission]: The permission string to check (e.g., `headline.read`).
  bool hasPermission(User user, String permission) {
    // Administrators have all permissions
    if (user.role == UserRole.admin) {
      return true;
    }

    // Check if the user's role is in the map and has the permission
    return rolePermissions[user.role]?.contains(permission) ?? false;
  }

  /// Checks if the given [user] has the [UserRole.admin] role.
  ///
  /// This is a convenience method for checks that are strictly limited
  /// to administrators, bypassing the permission map.
  ///
  /// - [user]: The authenticated user.
  bool isAdmin(User user) {
    return user.role == UserRole.admin;
  }
}
