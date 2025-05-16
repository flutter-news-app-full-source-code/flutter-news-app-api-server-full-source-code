import 'package:ht_api/src/permissions.dart';
import 'package:ht_shared/ht_shared.dart'; // Assuming User model is here

/// {@template authorization_service}
/// Service responsible for checking user permissions based on roles.
/// {@endtemplate}
class AuthorizationService {
  /// {@macro authorization_service}
  const AuthorizationService();

  /// Checks if the given [user] has the specified [permission].
  ///
  /// Assumes the [User] model has a `role` property (String).
  /// Returns `true` if the user has the permission, `false` otherwise.
  bool hasPermission(User user, Permission permission) {
    // Admins always have permission.
    // Assuming user.role exists and 'admin' is the admin role string.
    if (user.role == UserRole.admin) {
      return true;
    }

    // Get the permissions for the user's role.
    final permissionsForRole = rolePermissions[user.role];

    // If the role is not found or has no permissions, deny access.
    if (permissionsForRole == null) {
      return false;
    }

    // Check if the requested permission is in the set of permissions for the role.
    return permissionsForRole.contains(permission);
  }

  // Optional: Add methods for checking ownership or other complex authorization rules here later.
}
