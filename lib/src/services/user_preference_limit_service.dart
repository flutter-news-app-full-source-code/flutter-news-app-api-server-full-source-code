import 'package:ht_shared/ht_shared.dart';

/// {@template user_preference_limit_service}
/// Service responsible for enforcing user preference limits based on user role.
/// {@endtemplate}
abstract class UserPreferenceLimitService {
  /// {@macro user_preference_limit_service}
  const UserPreferenceLimitService();

  /// Checks if the user is allowed to add a *single* item of the given type,
  /// considering their current count of that item type and their role.
  ///
  /// This method is typically used when a user performs an action that adds
  /// one item, such as saving a single headline or following a single source.
  ///
  /// - [user]: The authenticated user.
  /// - [itemType]: The type of item being added (e.g., 'country', 'source',
  ///   'category', 'headline').
  /// - [currentCount]: The current number of items of this type the user has.
  ///
  /// Throws [ForbiddenException] if adding the item would exceed the user's
  /// limit for their role.
  Future<void> checkAddItem(User user, String itemType, int currentCount);

  /// Checks if the proposed *entire state* of the user's preferences,
  /// represented by [updatedPreferences], exceeds the limits based on their role.
  ///
  /// This method is typically used when the full [UserContentPreferences] object
  /// is being updated, such as when a user saves changes from a preferences screen.
  /// It validates the total counts across all relevant lists (followed countries,
  /// sources, categories, and saved headlines).
  ///
  /// - [user]: The authenticated user.
  /// - [updatedPreferences]: The proposed [UserContentPreferences] object.
  ///
  /// Throws [ForbiddenException] if any list within the preferences exceeds
  /// the user's limit for their role.
  Future<void> checkUpdatePreferences(
    User user,
    UserContentPreferences updatedPreferences,
  );
}
