import 'package:ht_api/src/rbac/permission_service.dart' show PermissionService;
import 'package:ht_api/src/rbac/permissions.dart';
import 'package:ht_shared/ht_shared.dart'; // Assuming UserRole is defined here

/// Defines the mapping between user roles and the permissions they possess.
///
/// This map is the core of the Role-Based Access Control (RBAC) system.
/// Each key is a [UserRole], and the associated value is a [Set] of
/// [Permissions] strings that users with that role are granted.
///
/// Note: Administrators typically have implicit access to all resources
/// regardless of this map, but including their permissions here can aid
/// documentation and clarity. The [PermissionService] should handle the
/// explicit admin bypass if desired.
final Map<UserRole, Set<String>> rolePermissions = {
  UserRole.admin: {
    // Admins typically have all permissions. Listing them explicitly
    // or handling the admin bypass in PermissionService are options.
    // For clarity, listing some key admin permissions here:
    Permissions.headlineCreate,
    Permissions.headlineRead,
    Permissions.headlineUpdate,
    Permissions.headlineDelete,
    Permissions.categoryCreate,
    Permissions.categoryRead,
    Permissions.categoryUpdate,
    Permissions.categoryDelete,
    Permissions.sourceCreate,
    Permissions.sourceRead,
    Permissions.sourceUpdate,
    Permissions.sourceDelete,
    Permissions.countryCreate,
    Permissions.countryRead,
    Permissions.countryUpdate,
    Permissions.countryDelete,
    Permissions.userRead, // Admins can read any user profile
    Permissions.userReadOwned,
    Permissions.userUpdateOwned,
    Permissions.userDeleteOwned,
    Permissions.appSettingsReadOwned,
    Permissions.appSettingsUpdateOwned,
    Permissions.userPreferencesReadOwned,
    Permissions.userPreferencesUpdateOwned,
    Permissions.remoteConfigReadAdmin,
    Permissions.remoteConfigUpdateAdmin,
    // Add all other permissions here for completeness if not using admin bypass
  },
  UserRole.standardUser: {
    // Standard users can read public/shared data
    Permissions.headlineRead,
    Permissions.categoryRead,
    Permissions.sourceRead,
    Permissions.countryRead,
    // Standard users can manage their own user-owned data
    Permissions.userReadOwned,
    Permissions.userUpdateOwned,
    Permissions.userDeleteOwned,
    Permissions.appSettingsReadOwned,
    Permissions.appSettingsUpdateOwned,
    Permissions.userPreferencesReadOwned,
    Permissions.userPreferencesUpdateOwned,
    // Add other permissions for standard users as needed
  },
  UserRole.guestUser: {
    // Guest users have very limited permissions, primarily reading public data
    Permissions.headlineRead,
    Permissions.categoryRead,
    Permissions.sourceRead,
    Permissions.countryRead,
    // Add other permissions for guest users as needed
  },
};
