import 'package:core/core.dart';

/// {@template user_preference_limit_service}
/// A service responsible for enforcing all user preference limits based on
/// the user's role and the application's remote configuration.
///
/// This service centralizes validation for both the `Interest` model and
/// the `UserContentPreferences` model (e.g., followed items, saved headlines).
/// {@endtemplate}
abstract class UserPreferenceLimitService {
  /// {@macro user_preference_limit_service}
  const UserPreferenceLimitService();

  /// Validates an updated [UserContentPreferences] object against all limits
  /// defined in `RemoteConfig`, including interests, followed items, and
  /// saved headlines.
  ///
  /// Throws a [ForbiddenException] if any limit is exceeded.
  Future<void> checkUserContentPreferencesLimits({
    required User user,
    required UserContentPreferences updatedPreferences,
    required UserContentPreferences currentPreferences,
  });
}
