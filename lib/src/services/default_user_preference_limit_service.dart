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

      // 2. Determine the limit based on user role and item type
      int limit;
      switch (user.role) {
        case UserRole.guestUser:
          if (itemType == 'headline') {
            limit = limits.guestSavedHeadlinesLimit;
          } else {
            // Applies to countries, sources, categories
            limit = limits.guestFollowedItemsLimit;
          }
        case UserRole.standardUser:
          if (itemType == 'headline') {
            limit = limits.authenticatedSavedHeadlinesLimit;
          } else {
            // Applies to countries, sources, categories
            limit = limits.authenticatedFollowedItemsLimit;
          }
        case UserRole.premiumUser:
          if (itemType == 'headline') {
            limit = limits.premiumSavedHeadlinesLimit;
          } else {
            limit = limits.premiumFollowedItemsLimit;
          }
        case UserRole.admin:
          // Admins have no limits
          return;
      }

      // 3. Check if adding the item would exceed the limit
      if (currentCount >= limit) {
        throw ForbiddenException(
          'You have reached the maximum number of $itemType items allowed '
          'for your account type (${user.role.name}).',
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

      // 2. Determine limits based on user role
      int followedItemsLimit;
      int savedHeadlinesLimit;

      switch (user.role) {
        case UserRole.guestUser:
          followedItemsLimit = limits.guestFollowedItemsLimit;
          savedHeadlinesLimit = limits.guestSavedHeadlinesLimit;
        case UserRole.standardUser:
          followedItemsLimit = limits.authenticatedFollowedItemsLimit;
          savedHeadlinesLimit = limits.authenticatedSavedHeadlinesLimit;
        case UserRole.premiumUser:
          followedItemsLimit = limits.premiumFollowedItemsLimit;
          savedHeadlinesLimit = limits.premiumSavedHeadlinesLimit;
        case UserRole.admin:
          // Admins have no limits
          return;
      }

      // 3. Check if proposed preferences exceed limits
      if (updatedPreferences.followedCountries.length > followedItemsLimit) {
        throw ForbiddenException(
          'You have reached the maximum number of followed countries allowed '
          'for your account type (${user.role.name}).',
        );
      }
      if (updatedPreferences.followedSources.length > followedItemsLimit) {
        throw ForbiddenException(
          'You have reached the maximum number of followed sources allowed '
          'for your account type (${user.role.name}).',
        );
      }
      if (updatedPreferences.followedCategories.length > followedItemsLimit) {
        throw ForbiddenException(
          'You have reached the maximum number of followed categories allowed '
          'for your account type (${user.role.name}).',
        );
      }
      if (updatedPreferences.savedHeadlines.length > savedHeadlinesLimit) {
        throw ForbiddenException(
          'You have reached the maximum number of saved headlines allowed '
          'for your account type (${user.role.name}).',
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
