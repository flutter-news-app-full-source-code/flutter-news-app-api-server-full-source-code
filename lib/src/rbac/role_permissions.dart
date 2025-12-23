import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

// --- Access Tier Permissions (for App Users) ---

final Set<String> _guestTierPermissions = {
  Permissions.headlineRead,
  Permissions.topicRead,
  Permissions.sourceRead,
  Permissions.countryRead,
  Permissions.languageRead,
  Permissions.appSettingsReadOwned,
  Permissions.appSettingsUpdateOwned,
  Permissions.userContentPreferencesReadOwned,
  Permissions.userContentPreferencesUpdateOwned,
  Permissions.userUpdateOwned,

  // Allow all app users to register and unregister their devices for push
  // notifications.
  Permissions.pushNotificationDeviceCreateOwned,
  Permissions.pushNotificationDeviceDeleteOwned,
  Permissions.pushNotificationDeviceReadOwned,

  // Allow all app users to manage their own in-app notifications.
  Permissions.inAppNotificationReadOwned,
  Permissions.inAppNotificationUpdateOwned,
  Permissions.inAppNotificationDeleteOwned,

  // UGC Permissions
  Permissions.engagementCreateOwned,
  Permissions.engagementReadOwned,
  Permissions.engagementUpdateOwned,
  Permissions.engagementDeleteOwned,
  Permissions.reportCreateOwned,
  Permissions.reportReadOwned,
  Permissions.appReviewCreateOwned,
  Permissions.appReviewReadOwned,
  Permissions.appReviewUpdateOwned,
};

final Set<String> _standardTierPermissions = {
  ..._guestTierPermissions,
  Permissions.userReadOwned,
  Permissions.userDeleteOwned,
};

final Set<String> _premiumTierPermissions = {
  ..._standardTierPermissions,
  // Bypassing limits is a premium feature.
  Permissions.userPreferenceBypassLimits,
};

// --- User Role Permissions (for Admin/Dashboard Users) ---

final Set<String> _userRolePermissions = {
  // All authenticated users, regardless of role, can read public config.
  Permissions.remoteConfigRead,
};
final Set<String> _publisherRolePermissions = {
  // Publishers need to read all content types to manage them effectively.
  Permissions.headlineRead,
  Permissions.topicRead,
  Permissions.sourceRead,
  Permissions.countryRead,
  Permissions.languageRead,
  Permissions.remoteConfigRead,

  // Publishers can manage headlines.
  Permissions.headlineCreate,
  Permissions.headlineUpdate,
  Permissions.headlineDelete,

  // Core dashboard access and quality-of-life permissions.
  Permissions.dashboardLogin,
  Permissions.rateLimitingBypass,

  // Publishers can send breaking news notifications.
  Permissions.pushNotificationSendBreakingNews,
};

final Set<String> _adminRolePermissions = {
  ..._publisherRolePermissions,
  Permissions.topicCreate,
  Permissions.topicUpdate,
  Permissions.topicDelete,
  Permissions.sourceCreate,
  Permissions.sourceUpdate,
  Permissions.sourceDelete,
  Permissions.countryCreate,
  Permissions.countryUpdate,
  Permissions.countryDelete,
  Permissions.languageCreate,
  Permissions.languageUpdate,
  Permissions.languageDelete,
  // Allows reading any user's profile.
  Permissions.userRead,
  // Allows updating any user's profile (e.g., changing their roles).
  // User creation and deletion are handled by the auth service, not the
  // generic data API.
  Permissions.userUpdate,
  Permissions.remoteConfigCreate,
  Permissions.remoteConfigUpdate,
  Permissions.remoteConfigDelete,

  // Analytics
  Permissions.analyticsRead,
};

/// Defines the mapping between user roles and access tiers to the permissions
/// they possess.
///
/// The `PermissionService` will look up a user's `role` and `tier` in this
/// map and combine the resulting permission sets to determine their total
/// access rights.
final Map<Enum, Set<String>> rolePermissions = {
  AccessTier.guest: _guestTierPermissions,
  AccessTier.standard: _standardTierPermissions,
  AccessTier.premium: _premiumTierPermissions,
  UserRole.user: _userRolePermissions,
  UserRole.publisher: _publisherRolePermissions,
  UserRole.admin: _adminRolePermissions,
};
