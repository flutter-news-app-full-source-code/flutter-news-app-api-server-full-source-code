import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/set_equality_helper.dart';
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
    required UserContentPreferences currentPreferences,
  }) async {
    _log.info(
      'Checking all user content preferences limits for user ${user.id}.',
    );
    final remoteConfig = await _remoteConfigRepository.read(
      id: _remoteConfigId,
    );
    final limits = remoteConfig.userPreferenceConfig;

    final (followedItemsLimit, savedHeadlinesLimit) = _getLimitsForRole(
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

    // --- 2. Check interest-specific limits ---
    final interestLimits = remoteConfig.interestConfig.limits[user.appRole];
    if (interestLimits == null) {
      _log.severe(
        'Interest limits not found for role ${user.appRole}. '
        'Denying request by default.',
      );
      throw const ForbiddenException('Interest limits are not configured.');
    }

    // Check total number of interests.
    if (updatedPreferences.interests.length > interestLimits.total) {
      _log.warning(
        'User ${user.id} exceeded total interest limit: '
        '${interestLimits.total} (attempted '
        '${updatedPreferences.interests.length}).',
      );
      throw ForbiddenException(
        'You have reached your limit of ${interestLimits.total} saved interests.',
      );
    }

    // Find the interest that was added or updated to check its specific limits.
    // This logic assumes only one interest is added or updated per request.
    final currentInterestIds = currentPreferences.interests
        .map((i) => i.id)
        .toSet();
    Interest? changedInterest;

    for (final updatedInterest in updatedPreferences.interests) {
      if (!currentInterestIds.contains(updatedInterest.id)) {
        // This is a newly added interest.
        changedInterest = updatedInterest;
        break;
      } else {
        // This is a potentially updated interest. Find the original.
        final originalInterest = currentPreferences.interests.firstWhere(
          (i) => i.id == updatedInterest.id,
        );
        if (updatedInterest != originalInterest) {
          changedInterest = updatedInterest;
          break;
        }
      }
    }

    // If an interest was added or updated, check its specific limits.
    if (changedInterest != null) {
      _log.info('Checking limits for changed interest: ${changedInterest.id}');

      // Check total number of pinned feed filters.
      final pinnedCount = updatedPreferences.interests
          .where((i) => i.isPinnedFeedFilter)
          .length;
      if (pinnedCount > interestLimits.pinnedFeedFilters) {
        _log.warning(
          'User ${user.id} exceeded pinned feed filter limit: '
          '${interestLimits.pinnedFeedFilters} (attempted $pinnedCount).',
        );
        throw ForbiddenException(
          'You have reached your limit of ${interestLimits.pinnedFeedFilters} '
          'pinned feed filters.',
        );
      }

      // Check notification subscription limits for each type.
      for (final deliveryType in changedInterest.deliveryTypes) {
        final notificationLimit = interestLimits.notifications[deliveryType];
        if (notificationLimit == null) {
          _log.severe(
            'Notification limit for type ${deliveryType.name} not found for '
            'role ${user.appRole}. Denying request by default.',
          );
          throw ForbiddenException(
            'Notification limits for ${deliveryType.name} are not configured.',
          );
        }

        final subscriptionCount = updatedPreferences.interests
            .where((i) => i.deliveryTypes.contains(deliveryType))
            .length;

        if (subscriptionCount > notificationLimit) {
          _log.warning(
            'User ${user.id} exceeded notification limit for '
            '${deliveryType.name}: $notificationLimit '
            '(attempted $subscriptionCount).',
          );
          throw ForbiddenException(
            'You have reached your limit of $notificationLimit '
            '${deliveryType.name} notification subscriptions.',
          );
        }
      }
    }

    _log.info(
      'All user content preferences limits check passed for user ${user.id}.',
    );
  }

  /// Helper to get the correct limits based on the user's role.
  (int, int) _getLimitsForRole(
    AppUserRole role,
    UserPreferenceConfig limits,
  ) {
    return switch (role) {
      AppUserRole.guestUser => (
        limits.guestFollowedItemsLimit,
        limits.guestSavedHeadlinesLimit,
      ),
      AppUserRole.standardUser => (
        limits.authenticatedFollowedItemsLimit,
        limits.authenticatedSavedHeadlinesLimit,
      ),
      AppUserRole.premiumUser => (
        limits.premiumFollowedItemsLimit,
        limits.premiumSavedHeadlinesLimit,
      ),
    };
  }
}
