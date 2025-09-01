import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

// --- App Role Permissions ---

final Set<String> _appGuestUserPermissions = {
  Permissions.headlineRead,
  Permissions.topicRead,
  Permissions.sourceRead,
  Permissions.countryRead,
  Permissions.languageRead,
  Permissions.userAppSettingsReadOwned,
  Permissions.userAppSettingsUpdateOwned,
  Permissions.userContentPreferencesReadOwned,
  Permissions.userContentPreferencesUpdateOwned,
  Permissions.remoteConfigRead,
  Permissions.localAdRead,
  // Allows a user to update their own User object. This is essential for
  // features like updating the `feedActionStatus` (e.g., when a user
  // dismisses an in-feed prompt, etc). The endpoint handler ensures only
  // non-sensitive fields can be modified.
  Permissions.userUpdateOwned,
};

final Set<String> _appStandardUserPermissions = {
  ..._appGuestUserPermissions,
  Permissions.userReadOwned,
  Permissions.userDeleteOwned,
};

final Set<String> _appPremiumUserPermissions = {
  ..._appStandardUserPermissions,
  // Future premium-only permissions can be added here.
};

// --- Dashboard Role Permissions ---

final Set<String> _dashboardPublisherPermissions = {
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
};

final Set<String> _dashboardAdminPermissions = {
  ..._dashboardPublisherPermissions,
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
  Permissions.userRead, // Allows reading any user's profile
  Permissions.remoteConfigCreate,
  Permissions.remoteConfigUpdate,
  Permissions.remoteConfigDelete,
  Permissions.userPreferenceBypassLimits,
  // Added localAd CRUD permissions for admins
  Permissions.localAdCreate,
  Permissions.localAdRead,
  Permissions.localAdUpdate,
  Permissions.localAdDelete,
};

/// Defines the mapping between user roles (both app and dashboard) and the
/// permissions they possess.
///
/// The `PermissionService` will look up a user's `appRole` and
/// `dashboardRole` in this map and combine the resulting permission sets to
/// determine their total access rights.
final Map<Enum, Set<String>> rolePermissions = {
  // App Roles
  AppUserRole.guestUser: _appGuestUserPermissions,
  AppUserRole.standardUser: _appStandardUserPermissions,
  AppUserRole.premiumUser: _appPremiumUserPermissions,
  // Dashboard Roles
  DashboardUserRole.none: {},
  DashboardUserRole.publisher: _dashboardPublisherPermissions,
  DashboardUserRole.admin: _dashboardAdminPermissions,
};
