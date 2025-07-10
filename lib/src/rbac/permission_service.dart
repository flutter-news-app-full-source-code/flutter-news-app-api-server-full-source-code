import 'package:ht_api/src/rbac/role_permissions.dart';
import 'package:ht_shared/ht_shared.dart';

/// {@template permission_service}
/// Service responsible for checking if a user has a specific permission.
///
/// This service uses the predefined [rolePermissions] map to determine a user's
/// access rights based on their `appRole` and `dashboardRole`. It also
/// includes an explicit check for the `admin` role, granting them all
/// permissions.
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

    // Get the permission sets for the user's app and dashboard roles.
    final appPermissions = rolePermissions[user.appRole] ?? const <String>{};
    final dashboardPermissions =
        rolePermissions[user.dashboardRole] ?? const <String>{};

    // Combine the permissions from both roles.
    final totalPermissions = {...appPermissions, ...dashboardPermissions};

    // Check if the combined set contains the required permission.
    return totalPermissions.contains(permission);
  }

  /// Checks if the given [user] has the `admin` dashboard role.
  ///
  /// This is a convenience method for checks that are strictly limited
  /// to administrators, bypassing the permission map.
  ///
  /// - [user]: The authenticated user.
  bool isAdmin(User user) {
    return user.dashboardRole == DashboardUserRole.admin;
  }
}
