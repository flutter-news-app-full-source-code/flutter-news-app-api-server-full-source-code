import 'package:ht_api/src/rbac/role_permissions.dart';
import 'package:ht_shared/ht_shared.dart';

/// {@template permission_service}
/// Service responsible for checking if a user has a specific permission.
///
/// This service uses the predefined [rolePermissions] map to determine
/// a user's access rights based on their roles. It also includes
/// an explicit check for the 'admin' role, granting them all permissions.
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
    // Administrators implicitly have all permissions.
    if (user.roles.contains(UserRoles.admin)) {
      return true;
    }

    // Check if any of the user's roles grant the required permission.
    return user.roles.any(
      (role) => rolePermissions[role]?.contains(permission) ?? false,
    );
  }

  /// Checks if the given [user] has the 'admin' role.
  ///
  /// This is a convenience method for checks that are strictly limited
  /// to administrators, bypassing the permission map.
  ///
  /// - [user]: The authenticated user.
  bool isAdmin(User user) {
    return user.roles.contains(UserRoles.admin);
  }
}
