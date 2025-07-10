import 'package:ht_api/src/rbac/permissions.dart';
import 'package:ht_shared/ht_shared.dart';

// --- App Role Permissions ---

final Set<String> _appGuestUserPermissions = {
  Permissions.headlineRead,
  Permissions.topicRead,
  Permissions.sourceRead,
  Permissions.countryRead,
  Permissions.userAppSettingsReadOwned,
  Permissions.userAppSettingsUpdateOwned,
  Permissions.userContentPreferencesReadOwned,
  Permissions.userContentPreferencesUpdateOwned,
  Permissions.remoteConfigRead,
};

final Set<String> _appStandardUserPermissions = {
  ..._appGuestUserPermissions,
  Permissions.userReadOwned,
  Permissions.userUpdateOwned,
  Permissions.userDeleteOwned,
};

final Set<String> _appPremiumUserPermissions = {
  ..._appStandardUserPermissions,
  // Future premium-only permissions can be added here.
};

// --- Dashboard Role Permissions ---

final Set<String> _dashboardPublisherPermissions = {
  Permissions.headlineCreate,
  Permissions.headlineUpdate,
  Permissions.headlineDelete,
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
  Permissions.userRead, // Allows reading any user's profile
  Permissions.remoteConfigCreate,
  Permissions.remoteConfigUpdate,
  Permissions.remoteConfigDelete,
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
