import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/user_preference_limit_service.dart';
import 'package:logging/logging.dart';

/// {@template default_user_preference_limit_service}
/// Default implementation of [UserPreferenceLimitService] that enforces limits
/// based on user role and the `InterestConfig` and `UserPreferenceConfig`
/// sections within the application's [RemoteConfig].
/// {@endtemplate}
class DefaultUserPreferenceLimitService implements UserPreferenceLimitService {
  /// {@macro default_user_preference_limit_service}
  const DefaultUserPreferenceLimitService({
    required DataRepository<RemoteConfig> remoteConfigRepository,
    required Logger log,
  }) : _remoteConfigRepository = remoteConfigRepository,
       _log = log;

  final DataRepository<RemoteConfig> _remoteConfigRepository;
  final Logger _log;

  // Assuming a fixed ID for the RemoteConfig document
  static const String _remoteConfigId = kRemoteConfigId;

  @override
  Future<void> checkUserContentPreferencesLimits({
    required User user,
    required UserContentPreferences updatedPreferences,
  }) async {
    _log.info(
      'Checking all user content preferences limits for user ${user.id}.',
    );
    final remoteConfig = await _remoteConfigRepository.read(
      id: _remoteConfigId,
    );
    final limits = remoteConfig.user.limits;

    // Retrieve all relevant limits for the user's role from the remote configuration.
    final (
      followedItemsLimit,
      savedHeadlinesLimit,
      savedHeadlineFiltersLimit,
      savedSourceFiltersLimit,
    ) = _getLimitsForRole(
      user.appRole,
      limits,
    );

    // --- 1. Check general preference limits ---
    if (updatedPreferences.followedCountries.length > followedItemsLimit) {
      _log.warning(
        'User ${user.id} exceeded followed countries limit: '
        '$followedItemsLimit (attempted '
        '${updatedPreferences.followedCountries.length}).',
      );
      throw ForbiddenException(
        'You have reached your limit of $followedItemsLimit followed countries.',
      );
    }

    if (updatedPreferences.followedSources.length > followedItemsLimit) {
      _log.warning(
        'User ${user.id} exceeded followed sources limit: '
        '$followedItemsLimit (attempted '
        '${updatedPreferences.followedSources.length}).',
      );
      throw ForbiddenException(
        'You have reached your limit of $followedItemsLimit followed sources.',
      );
    }

    if (updatedPreferences.followedTopics.length > followedItemsLimit) {
      _log.warning(
        'User ${user.id} exceeded followed topics limit: '
        '$followedItemsLimit (attempted '
        '${updatedPreferences.followedTopics.length}).',
      );
      throw ForbiddenException(
        'You have reached your limit of $followedItemsLimit followed topics.',
      );
    }

    if (updatedPreferences.savedHeadlines.length > savedHeadlinesLimit) {
      _log.warning(
        'User ${user.id} exceeded saved headlines limit: '
        '$savedHeadlinesLimit (attempted '
        '${updatedPreferences.savedHeadlines.length}).',
      );
      throw ForbiddenException(
        'You have reached your limit of $savedHeadlinesLimit saved headlines.',
      );
    }

    // --- 2. Check saved headline filter limits ---
    // Validate the total number of saved headline filters.
    if (updatedPreferences.savedHeadlineFilters.length >
        savedHeadlineFiltersLimit.total) {
      _log.warning(
        'User ${user.id} exceeded total saved headline filter limit: '
        '${savedHeadlineFiltersLimit.total} (attempted '
        '${updatedPreferences.savedHeadlineFilters.length}).',
      );
      throw ForbiddenException(
        'You have reached your limit of ${savedHeadlineFiltersLimit.total} '
        'saved headline filters.',
      );
    }

    // Validate the number of pinned saved headline filters.
    final pinnedHeadlineFilterCount = updatedPreferences.savedHeadlineFilters
        .where((f) => f.isPinned)
        .length;
    if (pinnedHeadlineFilterCount > savedHeadlineFiltersLimit.pinned) {
      _log.warning(
        'User ${user.id} exceeded pinned saved headline filter limit: '
        '${savedHeadlineFiltersLimit.pinned} (attempted $pinnedHeadlineFilterCount).',
      );
      throw ForbiddenException(
        'You have reached your limit of ${savedHeadlineFiltersLimit.pinned} '
        'pinned saved headline filters.',
      );
    }

    // Validate notification subscription limits for each delivery type for saved headline filters.
    if (savedHeadlineFiltersLimit.notificationSubscriptions != null) {
      for (final deliveryType
          in PushNotificationSubscriptionDeliveryType.values) {
        final notificationLimit =
            savedHeadlineFiltersLimit.notificationSubscriptions![deliveryType];
        if (notificationLimit == null) {
          // This indicates a misconfiguration in RemoteConfig if a deliveryType is expected but not present.
          _log.severe(
            'Notification limit for type ${deliveryType.name} not configured for '
            'role ${user.appRole} in savedHeadlineFiltersLimit. Denying request.',
          );
          throw ForbiddenException(
            'Notification limits for ${deliveryType.name} are not configured '
            'for saved headline filters.',
          );
        }

        final subscriptionCount = updatedPreferences.savedHeadlineFilters
            .where((f) => f.deliveryTypes.contains(deliveryType))
            .length;

        if (subscriptionCount > notificationLimit) {
          _log.warning(
            'User ${user.id} exceeded notification limit for '
            '${deliveryType.name} in saved headline filters: $notificationLimit '
            '(attempted $subscriptionCount).',
          );
          throw ForbiddenException(
            'You have reached your limit of $notificationLimit '
            '${deliveryType.name} notification subscriptions for saved headline filters.',
          );
        }
      }
    }

    // --- 3. Check saved source filter limits ---
    // Validate the total number of saved source filters.
    if (updatedPreferences.savedSourceFilters.length >
        savedSourceFiltersLimit.total) {
      _log.warning(
        'User ${user.id} exceeded total saved source filter limit: '
        '${savedSourceFiltersLimit.total} (attempted '
        '${updatedPreferences.savedSourceFilters.length}).',
      );
      throw ForbiddenException(
        'You have reached your limit of ${savedSourceFiltersLimit.total} '
        'saved source filters.',
      );
    }

    // Validate the number of pinned saved source filters.
    final pinnedSourceFilterCount = updatedPreferences.savedSourceFilters
        .where((f) => f.isPinned)
        .length;
    if (pinnedSourceFilterCount > savedSourceFiltersLimit.pinned) {
      _log.warning(
        'User ${user.id} exceeded pinned saved source filter limit: '
        '${savedSourceFiltersLimit.pinned} (attempted $pinnedSourceFilterCount).',
      );
      throw ForbiddenException(
        'You have reached your limit of ${savedSourceFiltersLimit.pinned} '
        'pinned saved source filters.',
      );
    }

    _log.info(
      'All user content preferences limits check passed for user ${user.id}.',
    );
  }

  /// Helper to retrieve all relevant user preference limits based on the user's role.
  ///
  /// Throws [StateError] if a required limit is not configured for the given role,
  /// indicating a misconfiguration in the remote config.
  (
    int followedItemsLimit,
    int savedHeadlinesLimit,
    SavedFilterLimits savedHeadlineFiltersLimit,
    SavedFilterLimits savedSourceFiltersLimit,
  )
  _getLimitsForRole(
    AppUserRole role,
    UserLimitsConfig limits,
  ) {
    final followedItemsLimit = limits.followedItems[role];
    if (followedItemsLimit == null) {
      throw StateError('Followed items limit not configured for role: $role');
    }

    final savedHeadlinesLimit = limits.savedHeadlines[role];
    if (savedHeadlinesLimit == null) {
      throw StateError('Saved headlines limit not configured for role: $role');
    }

    final savedHeadlineFiltersLimit = limits.savedHeadlineFilters[role];
    if (savedHeadlineFiltersLimit == null) {
      throw StateError(
        'Saved headline filters limit not configured for role: $role',
      );
    }

    final savedSourceFiltersLimit = limits.savedSourceFilters[role];
    if (savedSourceFiltersLimit == null) {
      throw StateError(
        'Saved source filters limit not configured for role: $role',
      );
    }

    return (
      followedItemsLimit,
      savedHeadlinesLimit,
      savedHeadlineFiltersLimit,
      savedSourceFiltersLimit,
    );
  }
}
