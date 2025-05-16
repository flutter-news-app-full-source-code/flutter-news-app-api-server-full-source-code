/// Defines the roles and permissions used in the RBAC system.
///
/// Permissions are defined as constants in the format `resource.action`.
/// Roles are defined as constants.
/// The `rolePermissions` map defines which permissions are granted to each role.

/// {@template role}
/// Defines the available user roles in the system.
/// {@endtemplate}
abstract class Role {
  /// Administrator role with full access.
  static const String admin = 'admin';

  /// Standard user role with limited access.
  static const String standardUser = 'standard_user';

  // Add other roles here as needed.
}

/// {@template permission}
/// Defines the available permissions in the system.
///
/// Permissions follow the format `resource.action`.
/// {@endtemplate}
abstract class Permission {
  // Headline Permissions
  static const String headlineRead = 'headline.read';
  static const String headlineCreate = 'headline.create';
  static const String headlineUpdate = 'headline.update';
  static const String headlineDelete = 'headline.delete';

  // Category Permissions
  static const String categoryRead = 'category.read';
  static const String categoryCreate = 'category.create';
  static const String categoryUpdate = 'category.update';
  static const String categoryDelete = 'category.delete';

  // Source Permissions
  static const String sourceRead = 'source.read';
  static const String sourceCreate = 'source.create';
  static const String sourceUpdate = 'source.update';
  static const String sourceDelete = 'source.delete';

  // Country Permissions
  static const String countryRead = 'country.read';
  static const String countryCreate = 'country.create';
  static const String countryUpdate = 'country.update';
  static const String countryDelete = 'country.delete';

  // User Settings Permissions
  static const String userSettingsRead = 'user_settings.read';
  static const String userSettingsUpdate = 'user_settings.update';
  // Note: User settings delete is handled via account deletion, no separate permission needed here.

  // Add other resource permissions here as needed.
}

/// A map defining which permissions are granted to each role.
///
/// The key is the role string, and the value is a set of permission strings.
final Map<String, Set<String>> rolePermissions = {
  Role.admin: {
    // Admins have all permissions. In a real system, you might have a more
    // sophisticated way to represent this, but listing them explicitly is clear.
    Permission.headlineRead,
    Permission.headlineCreate,
    Permission.headlineUpdate,
    Permission.headlineDelete,
    Permission.categoryRead,
    Permission.categoryCreate,
    Permission.categoryUpdate,
    Permission.categoryDelete,
    Permission.sourceRead,
    Permission.sourceCreate,
    Permission.sourceUpdate,
    Permission.sourceDelete,
    Permission.countryRead,
    Permission.countryCreate,
    Permission.countryUpdate,
    Permission.countryDelete,
    Permission.userSettingsRead,
    Permission.userSettingsUpdate,
    // Add other admin permissions here.
  },
  Role.standardUser: {
    // Standard users can read public data and manage their own settings.
    Permission.headlineRead,
    Permission.categoryRead,
    Permission.sourceRead,
    Permission.countryRead,
    Permission.userSettingsRead, // Can read their own settings
    Permission.userSettingsUpdate, // Can update their own settings
    // Add other standard user permissions here.
  },
  // Add mappings for other roles here.
};
