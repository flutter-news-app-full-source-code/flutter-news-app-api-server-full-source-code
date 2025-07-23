import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/user_preference_limit_service.dart';
import 'package:logging/logging.dart';

/// {@template default_user_preference_limit_service}
/// Default implementation of [UserPreferenceLimitService] that enforces limits
/// based on user role and [RemoteConfig].
/// {@endtemplate}
class DefaultUserPreferenceLimitService implements UserPreferenceLimitService {
  /// {@macro default_user_preference_limit_service}
  const DefaultUserPreferenceLimitService({
    required DataRepository<RemoteConfig> remoteConfigRepository,
    required PermissionService permissionService,
    required Logger log,
  }) : _remoteConfigRepository = remoteConfigRepository,
       _permissionService = permissionService,
       _log = log;

  final DataRepository<RemoteConfig> _remoteConfigRepository;
  final PermissionService _permissionService;
  final Logger _log;

  // Assuming a fixed ID for the RemoteConfig document
  static const String _remoteConfigId = kRemoteConfigId;

  @override
  Future<void> checkAddItem(
    User user,
    String itemType,
    int currentCount,
  ) async {
    try {
      // 1. Fetch the remote configuration to get limits
      final remoteConfig = await _remoteConfigRepository.read(
        id: _remoteConfigId,
      );
      final limits = remoteConfig.userPreferenceConfig;

      // Users with the bypass permission (e.g., admins) have no limits.
      if (_permissionService.hasPermission(
        user,
        Permissions.userPreferenceBypassLimits,
      )) {
        return;
      }

      // 2. Determine the limit based on the user's app role.
      int limit;
      String accountType;

      switch (user.appRole) {
        case AppUserRole.premiumUser:
          accountType = 'premium';
          limit = (itemType == 'headline')
              ? limits.premiumSavedHeadlinesLimit
              : limits.premiumFollowedItemsLimit;
        case AppUserRole.standardUser:
          accountType = 'standard';
          limit = (itemType == 'headline')
              ? limits.authenticatedSavedHeadlinesLimit
              : limits.authenticatedFollowedItemsLimit;
        case AppUserRole.guestUser:
          accountType = 'guest';
          limit = (itemType == 'headline')
              ? limits.guestSavedHeadlinesLimit
              : limits.guestFollowedItemsLimit;
      }

      // 3. Check if adding the item would exceed the limit
      if (currentCount >= limit) {
        throw ForbiddenException(
          'You have reached the maximum number of $itemType items allowed '
          'for your account type ($accountType).',
        );
      }
    } on HttpException {
      // Propagate known exceptions from repositories
      rethrow;
    } catch (e) {
      // Catch unexpected errors
      _log.severe(
        'Error checking limit for user ${user.id}, itemType $itemType: $e',
      );
      throw const OperationFailedException(
        'Failed to check user preference limits.',
      );
    }
  }

  @override
  Future<void> checkUpdatePreferences(
    User user,
    UserContentPreferences updatedPreferences,
  ) async {
    try {
      // 1. Fetch the remote configuration to get limits
      final remoteConfig = await _remoteConfigRepository.read(
        id: _remoteConfigId,
      );
      final limits = remoteConfig.userPreferenceConfig;

      // Users with the bypass permission (e.g., admins) have no limits.
      if (_permissionService.hasPermission(
        user,
        Permissions.userPreferenceBypassLimits,
      )) {
        return;
      }

      // 2. Determine limits based on the user's app role.
      int followedItemsLimit;
      int savedHeadlinesLimit;
      String accountType;

      switch (user.appRole) {
        case AppUserRole.premiumUser:
          accountType = 'premium';
          followedItemsLimit = limits.premiumFollowedItemsLimit;
          savedHeadlinesLimit = limits.premiumSavedHeadlinesLimit;
        case AppUserRole.standardUser:
          accountType = 'standard';
          followedItemsLimit = limits.authenticatedFollowedItemsLimit;
          savedHeadlinesLimit = limits.authenticatedSavedHeadlinesLimit;
        case AppUserRole.guestUser:
          accountType = 'guest';
          followedItemsLimit = limits.guestFollowedItemsLimit;
          savedHeadlinesLimit = limits.guestSavedHeadlinesLimit;
      }

      // 3. Check if proposed preferences exceed limits
      if (updatedPreferences.followedCountries.length > followedItemsLimit) {
        throw ForbiddenException(
          'You have reached the maximum number of followed countries allowed '
          'for your account type ($accountType).',
        );
      }
      if (updatedPreferences.followedSources.length > followedItemsLimit) {
        throw ForbiddenException(
          'You have reached the maximum number of followed sources allowed '
          'for your account type ($accountType).',
        );
      }
      if (updatedPreferences.followedTopics.length > followedItemsLimit) {
        throw ForbiddenException(
          'You have reached the maximum number of followed topics allowed '
          'for your account type ($accountType).',
        );
      }
      if (updatedPreferences.savedHeadlines.length > savedHeadlinesLimit) {
        throw ForbiddenException(
          'You have reached the maximum number of saved headlines allowed '
          'for your account type ($accountType).',
        );
      }
    } on HttpException {
      // Propagate known exceptions from repositories
      rethrow;
    } catch (e) {
      // Catch unexpected errors
      _log.severe('Error checking update limits for user ${user.id}: $e');
      throw const OperationFailedException(
        'Failed to check user preference update limits.',
      );
    }
  }
}
