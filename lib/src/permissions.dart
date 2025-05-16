import 'package:ht_shared/ht_shared.dart';

// ignore_for_file: public_member_api_docs

/// Defines the roles and permissions used in the RBAC system.
///
/// Permissions are defined as constants in the format `resource.action`.
/// Roles are defined as constants.
/// The `rolePermissions` map defines which permissions are granted to each role.

/// A map defining which permissions are granted to each role.
///
/// The key is the role string, and the value is a set of permission strings.
final Map<UserRole, Set<Permission>> rolePermissions = {
  UserRole.admin: {
    // Admins have all permissions. You might have a more
    // sophisticated way to represent this, but listing them explicitly is clear.
    const Permission(name: 'headlineRead'),
    const Permission(name: 'headlineCreate'),
    const Permission(name: 'headlineUpdate'),
    const Permission(name: 'headlineDelete'),
    const Permission(name: 'categoryRead'),
    const Permission(name: 'categoryCreate'),
    const Permission(name: 'categoryUpdate'),
    const Permission(name: 'categoryDelete'),
    const Permission(name: 'sourceRead'),
    const Permission(name: 'sourceCreate'),
    const Permission(name: 'sourceUpdate'),
    const Permission(name: 'sourceDelete'),
    const Permission(name: 'countryRead'),
    const Permission(name: 'countryCreate'),
    const Permission(name: 'countryUpdate'),
    const Permission(name: 'countryDelete'),
    const Permission(name: 'userSettingsRead'),
    const Permission(name: 'userSettingsUpdate'),
    // Add other admin permissions here.
  },
  UserRole.standardUser: {
    // Standard users can read public data and manage their own settings.
    const Permission(name: 'headlineRead'),
    const Permission(name: 'categoryRead'),
    const Permission(name: 'sourceRead'),
    const Permission(name: 'countryRead'),
    const Permission(name: 'userSettingsRead'), // Can read their own settings
    const Permission(
      name: 'userSettingsUpdate',
    ), // Can update their own settings
    // Add other standard user permissions here.
  },
  // Add mappings for other roles here.
};
