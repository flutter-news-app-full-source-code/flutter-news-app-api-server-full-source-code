// ignore_for_file: public_member_api_docs

/// Defines the available permissions in the system.
///
/// Permissions follow the format `resource.action`.
abstract class Permissions {
  // Headline Permissions
  static const String headlineCreate = 'headline.create';
  static const String headlineRead = 'headline.read';
  static const String headlineUpdate = 'headline.update';
  static const String headlineDelete = 'headline.delete';

  // Category Permissions
  static const String categoryCreate = 'category.create';
  static const String categoryRead = 'category.read';
  static const String categoryUpdate = 'category.update';
  static const String categoryDelete = 'category.delete';

  // Source Permissions
  static const String sourceCreate = 'source.create';
  static const String sourceRead = 'source.read';
  static const String sourceUpdate = 'source.update';
  static const String sourceDelete = 'source.delete';

  // Country Permissions
  static const String countryCreate = 'country.create';
  static const String countryRead = 'country.read';
  static const String countryUpdate = 'country.update';
  static const String countryDelete = 'country.delete';

  // User Permissions
  // Allows reading any user profile (e.g., for admin or public profiles)
  static const String userRead = 'user.read';
  // Allows reading the authenticated user's own profile
  static const String userReadOwned = 'user.read_owned';
  // Allows updating the authenticated user's own profile
  static const String userUpdateOwned = 'user.update_owned';
  // Allows deleting the authenticated user's own account
  static const String userDeleteOwned = 'user.delete_owned';

  // App Settings Permissions (User-owned)
  static const String appSettingsReadOwned = 'app_settings.read_owned';
  static const String appSettingsUpdateOwned = 'app_settings.update_owned';

  // User Preferences Permissions (User-owned)
  static const String userPreferencesReadOwned = 'user_preferences.read_owned';
  static const String userPreferencesUpdateOwned =
      'user_preferences.update_owned';

  // Remote Config Permissions (Admin-owned/managed)
  static const String remoteConfigReadAdmin = 'remote_config.read_admin';
  static const String remoteConfigUpdateAdmin = 'remote_config.update_admin';

  // Add other permissions as needed for future models/features
}
