import 'package:ht_api/src/rbac/permission_service.dart' show PermissionService;
import 'package:ht_api/src/rbac/permissions.dart';
import 'package:ht_shared/ht_shared.dart';

final Set<String> _guestUserPermissions = {
  Permissions.headlineRead,
  Permissions.categoryRead,
  Permissions.sourceRead,
  Permissions.countryRead,
  Permissions.appSettingsReadOwned,
  Permissions.appSettingsUpdateOwned,
  Permissions.userPreferencesReadOwned,
  Permissions.userPreferencesUpdateOwned,
  Permissions.appConfigRead,
};

final Set<String> _standardUserPermissions = {
  ..._guestUserPermissions,
  Permissions.userReadOwned,
  Permissions.userUpdateOwned,
  Permissions.userDeleteOwned,
};

// For now, premium users have the same permissions as standard users,
// but this set can be expanded later for premium-specific features.
final Set<String> _premiumUserPermissions = {
  ..._standardUserPermissions,
};

final Set<String> _adminPermissions = {
  ..._standardUserPermissions,
  Permissions.headlineCreate,
  Permissions.headlineUpdate,
  Permissions.headlineDelete,
  Permissions.categoryCreate,
  Permissions.categoryUpdate,
  Permissions.categoryDelete,
  Permissions.sourceCreate,
  Permissions.sourceUpdate,
  Permissions.sourceDelete,
  Permissions.countryCreate,
  Permissions.countryUpdate,
  Permissions.countryDelete,
  Permissions.userRead,
  Permissions.appConfigCreate,
  Permissions.appConfigUpdate,
  Permissions.appConfigDelete,
};

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
  UserRole.guestUser: _guestUserPermissions,
  UserRole.standardUser: _standardUserPermissions,
  UserRole.premiumUser: _premiumUserPermissions, // Added premium user
  UserRole.admin: _adminPermissions,
};
