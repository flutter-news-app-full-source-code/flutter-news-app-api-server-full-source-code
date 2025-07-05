import 'package:ht_api/src/services/user_preference_limit_service.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_shared/ht_shared.dart';

/// {@template default_user_preference_limit_service}
/// Default implementation of [UserPreferenceLimitService] that enforces limits
/// based on user role and [AppConfig].
/// {@endtemplate}
class DefaultUserPreferenceLimitService implements UserPreferenceLimitService {
  /// {@macro default_user_preference_limit_service}
  const DefaultUserPreferenceLimitService({
    required HtDataRepository<AppConfig> appConfigRepository,
    // Removed unused UserContentPreferencesRepository
  }) : _appConfigRepository = appConfigRepository;

  final HtDataRepository<AppConfig> _appConfigRepository;

  // Assuming a fixed ID for the AppConfig document
  static const String _appConfigId = 'app_config';

  @override
  Future<void> checkAddItem(
    User user,
    String itemType,
    int currentCount,
  ) async {
    try {
      // 1. Fetch the application configuration to get limits
      final appConfig = await _appConfigRepository.read(id: _appConfigId);
      final limits = appConfig.userPreferenceLimits;

      // Admins have no limits.
      if (user.roles.contains(UserRoles.admin)) {
        return;
      }

      // 2. Determine the limit based on the user's highest role.
      int limit;
      String accountType;

      if (user.roles.contains(UserRoles.premiumUser)) {
        accountType = 'premium';
        limit = (itemType == 'headline')
            ? limits.premiumSavedHeadlinesLimit
            : limits.premiumFollowedItemsLimit;
      } else if (user.roles.contains(UserRoles.standardUser)) {
        accountType = 'standard';
        limit = (itemType == 'headline')
            ? limits.authenticatedSavedHeadlinesLimit
            : limits.authenticatedFollowedItemsLimit;
      } else if (user.roles.contains(UserRoles.guestUser)) {
        accountType = 'guest';
        limit = (itemType == 'headline')
            ? limits.guestSavedHeadlinesLimit
            : limits.guestFollowedItemsLimit;
      } else {
        // Fallback for users with unknown or no roles.
        throw const ForbiddenException(
          'Cannot determine preference limits for this user account.',
        );
      }

      // 3. Check if adding the item would exceed the limit
      if (currentCount >= limit) {
        throw ForbiddenException(
          'You have reached the maximum number of $itemType items allowed '
          'for your account type ($accountType).',
        );
      }
    } on HtHttpException {
      // Propagate known exceptions from repositories
      rethrow;
    } catch (e) {
      // Catch unexpected errors
      print('Error checking limit for user ${user.id}, itemType $itemType: $e');
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
      // 1. Fetch the application configuration to get limits
      final appConfig = await _appConfigRepository.read(id: _appConfigId);
      final limits = appConfig.userPreferenceLimits;

      // Admins have no limits.
      if (user.roles.contains(UserRoles.admin)) {
        return;
      }

      // 2. Determine limits based on the user's highest role.
      int followedItemsLimit;
      int savedHeadlinesLimit;
      String accountType;

      if (user.roles.contains(UserRoles.premiumUser)) {
        accountType = 'premium';
        followedItemsLimit = limits.premiumFollowedItemsLimit;
        savedHeadlinesLimit = limits.premiumSavedHeadlinesLimit;
      } else if (user.roles.contains(UserRoles.standardUser)) {
        accountType = 'standard';
        followedItemsLimit = limits.authenticatedFollowedItemsLimit;
        savedHeadlinesLimit = limits.authenticatedSavedHeadlinesLimit;
      } else if (user.roles.contains(UserRoles.guestUser)) {
        accountType = 'guest';
        followedItemsLimit = limits.guestFollowedItemsLimit;
        savedHeadlinesLimit = limits.guestSavedHeadlinesLimit;
      } else {
        // Fallback for users with unknown or no roles.
        throw const ForbiddenException(
          'Cannot determine preference limits for this user account.',
        );
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
      if (updatedPreferences.followedCategories.length > followedItemsLimit) {
        throw ForbiddenException(
          'You have reached the maximum number of followed categories allowed '
          'for your account type ($accountType).',
        );
      }
      if (updatedPreferences.savedHeadlines.length > savedHeadlinesLimit) {
        throw ForbiddenException(
          'You have reached the maximum number of saved headlines allowed '
          'for your account type ($accountType).',
        );
      }
    } on HtHttpException {
      // Propagate known exceptions from repositories
      rethrow;
    } catch (e) {
      // Catch unexpected errors
      print('Error checking update limits for user ${user.id}: $e');
      throw const OperationFailedException(
        'Failed to check user preference update limits.',
      );
    }
  }
}
