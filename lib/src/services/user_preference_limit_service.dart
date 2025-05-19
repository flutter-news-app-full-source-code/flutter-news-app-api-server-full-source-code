import 'package:ht_shared/ht_shared.dart';

/// {@template user_preference_limit_service}
/// Service responsible for enforcing user preference limits based on user role.
/// {@endtemplate}
abstract class UserPreferenceLimitService {
  /// {@macro user_preference_limit_service}
  const UserPreferenceLimitService();

  /// Checks if the user is allowed to add an item of the given type,
  /// considering their current count of that item type and their role.
  ///
  /// - [user]: The authenticated user.
  /// - [itemType]: The type of item being added (e.g., 'country', 'source',
  ///   'category', 'headline').
  /// - [currentCount]: The current number of items of this type the user has.
  ///
  /// Throws [ForbiddenException] if adding the item would exceed the user's
  /// limit for their role.
  Future<void> checkAddItem(User user, String itemType, int currentCount);

  /// Checks if the proposed [updatedPreferences] for the user exceed
  /// the limits based on their role.
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
