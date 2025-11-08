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
      final isFollowedItem =
          itemType == 'country' || itemType == 'source' || itemType == 'topic';

      switch (user.appRole) {
        case AppUserRole.premiumUser:
          accountType = 'premium';
          limit = isFollowedItem
              ? limits.premiumFollowedItemsLimit
              : (itemType == 'headline')
              ? limits.premiumSavedHeadlinesLimit
              : limits.premiumSavedFiltersLimit;
        case AppUserRole.standardUser:
          accountType = 'standard';
          limit = isFollowedItem
              ? limits.authenticatedFollowedItemsLimit
              : (itemType == 'headline')
              ? limits.authenticatedSavedHeadlinesLimit
              : limits.authenticatedSavedFiltersLimit;
        case AppUserRole.guestUser:
          accountType = 'guest';
          limit = isFollowedItem
              ? limits.guestFollowedItemsLimit
              : (itemType == 'headline')
              ? limits.guestSavedHeadlinesLimit
              : limits.guestSavedFiltersLimit;
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
      int savedFiltersLimit;
      String accountType;

      switch (user.appRole) {
        case AppUserRole.premiumUser:
          accountType = 'premium';
          followedItemsLimit = limits.premiumFollowedItemsLimit;
          savedHeadlinesLimit = limits.premiumSavedHeadlinesLimit;
          savedFiltersLimit = limits.premiumSavedFiltersLimit;
        case AppUserRole.standardUser:
          accountType = 'standard';
          followedItemsLimit = limits.authenticatedFollowedItemsLimit;
          savedHeadlinesLimit = limits.authenticatedSavedHeadlinesLimit;
          savedFiltersLimit = limits.authenticatedSavedFiltersLimit;
        case AppUserRole.guestUser:
          accountType = 'guest';
          followedItemsLimit = limits.guestFollowedItemsLimit;
          savedHeadlinesLimit = limits.guestSavedHeadlinesLimit;
          savedFiltersLimit = limits.guestSavedFiltersLimit;
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
      if (updatedPreferences.savedFilters.length > savedFiltersLimit) {
        throw ForbiddenException(
          'You have reached the maximum number of saved filters allowed '
          'for your account type ($accountType).',
        );
      }

      // 4. Check notification subscription limits (per delivery type).
      _log.info(
        'Checking notification subscription limits for user ${user.id}...',
      );
      final pushConfig = remoteConfig.pushNotificationConfig;

      // Iterate through each possible delivery type defined in the enum.
      for (final deliveryType
          in PushNotificationSubscriptionDeliveryType.values) {
        // Get the specific limit for this delivery type and user role.
        final limit =
            pushConfig
                .deliveryConfigs[deliveryType]
                ?.visibleTo[user.appRole]
                ?.subscriptionLimit ??
            0;

        // Count how many of the user's current subscriptions include this
        // specific delivery type.
        final count = updatedPreferences.notificationSubscriptions
            .where((sub) => sub.deliveryTypes.contains(deliveryType))
            .length;

        _log.finer(
          'User ${user.id} has $count subscriptions of type '
          '${deliveryType.name} (limit: $limit).',
        );

        // If the count for this specific type exceeds its limit, throw.
        if (count > limit) {
          throw ForbiddenException(
            'You have reached the maximum number of subscriptions for '
            '${deliveryType.name} notifications allowed for your account '
            'type ($accountType).',
          );
        }
      }

      _log.info(
        'All user preference limits for user ${user.id} are within range.',
      );
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
