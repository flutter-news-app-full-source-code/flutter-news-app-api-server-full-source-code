import 'package:core/core.dart';

/// {@template user_action_limit_service}
/// A service responsible for enforcing all user-related limits based on
/// the user's role and the application's remote configuration.
///
/// This service centralizes validation for both static preference counts
/// (e.g., number of saved filters) and transactional, time-windowed actions
/// (e.g., number of engagements or reports per day).
/// {@endtemplate}
abstract class UserActionLimitService {
  /// {@macro user_action_limit_service}
  const UserActionLimitService();

  /// Validates an updated [UserContentPreferences] object against all limits
  /// for preference counts (e.g., followed items, saved headlines).
  ///
  /// Throws a [ForbiddenException] if any limit is exceeded.
  Future<void> checkUserContentPreferencesLimits({
    required User user,
    required UserContentPreferences updatedPreferences,
  });

  /// Validates if a user can create a new [Engagement].
  ///
  /// This method checks against `reactionsPerDay` and, if the engagement
  /// contains a comment, also checks against `commentsPerDay`.
  Future<void> checkEngagementCreationLimit(
      {required User user, required Engagement engagement});

  /// Validates if a user can create a new [Report].
  ///
  /// This method checks against the `reportsPerDay` limit.
  Future<void> checkReportCreationLimit({required User user});
}
