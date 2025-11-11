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
  Future<void> checkInterestLimits({
    required User user,
    required Interest interest,
    required List<Interest> existingInterests,
  }) async {
    _log.info('Checking interest limits for user ${user.id}.');
    final remoteConfig = await _remoteConfigRepository.read(
      id: _remoteConfigId,
    );
    final limits = remoteConfig.interestConfig.limits[user.appRole];

    if (limits == null) {
      _log.severe(
        'Interest limits not found for role ${user.appRole}. '
        'Denying request by default.',
      );
      throw const ForbiddenException('Interest limits are not configured.');
    }

    // 1. Check total number of interests.
    final newTotal = existingInterests.length + 1;
    if (newTotal > limits.total) {
      _log.warning(
        'User ${user.id} exceeded total interest limit: '
        '${limits.total} (attempted $newTotal).',
      );
      throw ForbiddenException(
        'You have reached your limit of ${limits.total} saved interests.',
      );
    }

    // 2. Check total number of pinned feed filters.
    if (interest.isPinnedFeedFilter) {
      final pinnedCount =
          existingInterests.where((i) => i.isPinnedFeedFilter).length + 1;
      if (pinnedCount > limits.pinnedFeedFilters) {
        _log.warning(
          'User ${user.id} exceeded pinned feed filter limit: '
          '${limits.pinnedFeedFilters} (attempted $pinnedCount).',
        );
        throw ForbiddenException(
          'You have reached your limit of ${limits.pinnedFeedFilters} '
          'pinned feed filters.',
        );
      }
    }

    // 3. Check notification subscription limits for each type.
    for (final deliveryType in interest.deliveryTypes) {
      final notificationLimit = limits.notifications[deliveryType];
      if (notificationLimit == null) {
        _log.severe(
          'Notification limit for type ${deliveryType.name} not found for '
          'role ${user.appRole}. Denying request by default.',
        );
        throw ForbiddenException(
          'Notification limits for ${deliveryType.name} are not configured.',
        );
      }

      final subscriptionCount =
          existingInterests
              .where((i) => i.deliveryTypes.contains(deliveryType))
              .length +
          1;

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

    _log.info('Interest limits check passed for user ${user.id}.');
  }

  @override
  Future<void> checkUserContentPreferencesLimits({
    required User user,
    required UserContentPreferences updatedPreferences,
  }) async {
    _log.info('Checking user content preferences limits for user ${user.id}.');
    final remoteConfig = await _remoteConfigRepository.read(
      id: _remoteConfigId,
    );
    final limits = remoteConfig.userPreferenceConfig;

    final (followedItemsLimit, savedHeadlinesLimit) = _getLimitsForRole(
      user.appRole,
      limits,
    );

    // Check followed countries
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

    // Check followed sources
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

    // Check followed topics
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

    // Check saved headlines
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

    _log.info(
      'User content preferences limits check passed for user ${user.id}.',
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
