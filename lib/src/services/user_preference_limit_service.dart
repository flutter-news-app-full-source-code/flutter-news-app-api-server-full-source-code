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

  /// Validates a new or updated [Interest] against the user's role-based
  /// limits defined in `InterestConfig`.
  ///
  /// This method checks multiple limits:
  /// - The total number of interests.
  /// - The number of interests marked as pinned feed filters.
  /// - The number of subscriptions for each notification delivery type across
  ///   all of the user's interests.
  ///
  /// - [user]: The authenticated user.
  /// - [interest]: The `Interest` object being created or updated.
  /// - [existingInterests]: A list of the user's other existing interests,
  ///   used to calculate total counts.
  ///
  /// Throws a [ForbiddenException] if any limit is exceeded.
  Future<void> checkInterestLimits({
    required User user,
    required Interest interest,
    required List<Interest> existingInterests,
  });

  /// Validates an updated [UserContentPreferences] object against the limits
  /// defined in `UserPreferenceConfig`.
  ///
  /// This method checks the total counts for followed items (countries,
  /// sources, topics) and saved headlines.
  /// Throws a [ForbiddenException] if any limit is exceeded.
  Future<void> checkUserContentPreferencesLimits({
    required User user,
    required UserContentPreferences updatedPreferences,
  });
}
