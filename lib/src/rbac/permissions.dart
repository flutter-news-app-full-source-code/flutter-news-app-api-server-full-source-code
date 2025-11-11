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

  // Topic Permissions
  static const String topicCreate = 'topic.create';
  static const String topicRead = 'topic.read';
  static const String topicUpdate = 'topic.update';
  static const String topicDelete = 'topic.delete';

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

  // Language Permissions
  static const String languageCreate = 'language.create';
  static const String languageRead = 'language.read';
  static const String languageUpdate = 'language.update';
  static const String languageDelete = 'language.delete';

  // User Permissions
  // Allows reading any user profile (e.g., for admin or public profiles)
  static const String userRead = 'user.read';
  // Allows reading the authenticated user's own profile
  static const String userReadOwned = 'user.read_owned';
  // Allows updating the authenticated user's own profile
  static const String userUpdateOwned = 'user.update_owned';
  // Allows deleting the authenticated user's own account
  static const String userDeleteOwned = 'user.delete_owned';

  // Allows updating any user's profile (admin-only).
  // This is distinct from `userUpdateOwned`, which allows a user to update
  // their own record.
  static const String userUpdate = 'user.update';

  // User App Settings Permissions (User-owned)
  static const String userAppSettingsReadOwned = 'user_app_settings.read_owned';
  static const String userAppSettingsUpdateOwned =
      'user_app_settings.update_owned';

  // User Content Preferences Permissions (User-owned)
  static const String userContentPreferencesReadOwned =
      'user_content_preferences.read_owned';
  static const String userContentPreferencesUpdateOwned =
      'user_content_preferences.update_owned';

  // Remote Config Permissions (Global/Managed)
  static const String remoteConfigCreate = 'remote_config.create';
  static const String remoteConfigRead = 'remote_config.read';
  static const String remoteConfigUpdate = 'remote_config.update';
  static const String remoteConfigDelete = 'remote_config.delete';

  // Dashboard Permissions
  static const String dashboardLogin = 'dashboard.login';

  // User Preference Permissions
  static const String userPreferenceBypassLimits =
      'user_preference.bypass_limits';

  // Local Ad Permissions
  static const String localAdCreate = 'local_ad.create';
  static const String localAdRead = 'local_ad.read';
  static const String localAdUpdate = 'local_ad.update';
  static const String localAdDelete = 'local_ad.delete';

  // General System Permissions
  static const String rateLimitingBypass = 'rate_limiting.bypass';

  // Push Notification Permissions
  /// Allows sending breaking news push notifications.
  ///
  /// This permission is typically granted to dashboard roles like
  /// 'publisher' or 'admin'.
  static const String pushNotificationSendBreakingNews =
      'push_notification.send_breaking_news';

  // Push Notification Device Permissions (User-owned)
  static const String pushNotificationDeviceCreateOwned =
      'push_notification_device.create_owned';
  static const String pushNotificationDeviceDeleteOwned =
      'push_notification_device.delete_owned';

  // In-App Notification Permissions (User-owned)
  /// Allows reading the user's own in-app notifications.
  static const String inAppNotificationReadOwned =
      'in_app_notification.read_owned';

  /// Allows updating the user's own in-app notifications (e.g., marking as read).
  static const String inAppNotificationUpdateOwned =
      'in_app_notification.update_owned';

  /// Allows deleting the user's own in-app notifications.
  static const String inAppNotificationDeleteOwned =
      'in_app_notification.delete_owned';
}
