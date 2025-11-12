import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/database/migration.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template refactor_user_preferences_and_remote_config}
/// A migration to refactor the database schema to align with the updated
/// `UserContentPreferences` and `RemoteConfig` models from the core package.
///
/// This migration performs two critical transformations:
///
/// 1.  **User Preferences Transformation:** It iterates through all
///     `user_content_preferences` documents. For each user, it adds the new
///     `savedHeadlineFilters` and `savedSourceFilters` fields as empty lists
///     and removes the now-obsolete `interests` field.
///
/// 2.  **Remote Config Transformation:** It updates the single `remote_configs`
///     document by removing the deprecated `interestConfig` and replacing the
///     individual limit fields in `userPreferenceConfig` with the new,
///     flexible role-based map structure.
/// {@endtemplate}
class RefactorUserPreferencesAndRemoteConfig extends Migration {
  /// {@macro refactor_user_preferences_and_remote_config}
  RefactorUserPreferencesAndRemoteConfig()
    : super(
        prDate: '20251112000000',
        prId: '78',
        prSummary:
            'Refactors UserContentPreferences and RemoteConfig to support new SavedFilter models.',
      );

  @override
  Future<void> up(Db db, Logger log) async {
    log.info('Starting migration: RefactorUserPreferencesAndRemoteConfig.up');

    // --- 1. Migrate user_content_preferences ---
    log.info('Migrating user_content_preferences collection...');
    final preferencesCollection = db.collection('user_content_preferences');
    final result = await preferencesCollection.updateMany(
      where.exists('interests'),
      modify
          .set('savedHeadlineFilters', <dynamic>[])
          .set('savedSourceFilters', <dynamic>[])
          .unset('interests'),
    );
    log.info(
      'Updated user_content_preferences: ${result.nModified} documents modified.',
    );

    // --- 2. Migrate remote_configs ---
    log.info('Migrating remote_configs collection...');
    final remoteConfigCollection = db.collection('remote_configs');
    final remoteConfig = await remoteConfigCollection.findOne();

    if (remoteConfig != null) {
      // Define the new UserPreferenceConfig structure based on the new model.
      // This uses the structure from the "NEW REMOTE CONFIG" example.
      const newConfig = UserPreferenceConfig(
        followedItemsLimit: {
          AppUserRole.guestUser: 5,
          AppUserRole.standardUser: 15,
          AppUserRole.premiumUser: 30,
        },
        savedHeadlinesLimit: {
          AppUserRole.guestUser: 10,
          AppUserRole.standardUser: 30,
          AppUserRole.premiumUser: 100,
        },
        savedHeadlineFiltersLimit: {
          AppUserRole.guestUser: SavedFilterLimits(
            total: 3,
            pinned: 3,
            notificationSubscriptions: {
              PushNotificationSubscriptionDeliveryType.breakingOnly: 1,
              PushNotificationSubscriptionDeliveryType.dailyDigest: 0,
              PushNotificationSubscriptionDeliveryType.weeklyRoundup: 0,
            },
          ),
          AppUserRole.standardUser: SavedFilterLimits(
            total: 10,
            pinned: 5,
            notificationSubscriptions: {
              PushNotificationSubscriptionDeliveryType.breakingOnly: 3,
              PushNotificationSubscriptionDeliveryType.dailyDigest: 2,
              PushNotificationSubscriptionDeliveryType.weeklyRoundup: 2,
            },
          ),
          AppUserRole.premiumUser: SavedFilterLimits(
            total: 25,
            pinned: 10,
            notificationSubscriptions: {
              PushNotificationSubscriptionDeliveryType.breakingOnly: 10,
              PushNotificationSubscriptionDeliveryType.dailyDigest: 10,
              PushNotificationSubscriptionDeliveryType.weeklyRoundup: 10,
            },
          ),
        },
        savedSourceFiltersLimit: {
          AppUserRole.guestUser: SavedFilterLimits(total: 3, pinned: 3),
          AppUserRole.standardUser: SavedFilterLimits(total: 10, pinned: 5),
          AppUserRole.premiumUser: SavedFilterLimits(total: 25, pinned: 10),
        },
      );

      await remoteConfigCollection.updateOne(
        where.id(remoteConfig['_id'] as ObjectId),
        modify
            // Set the entire userPreferenceConfig to the new structure
            .set('userPreferenceConfig', newConfig.toJson())
            // Remove the obsolete interestConfig
            .unset('interestConfig'),
      );
      log.info('Successfully migrated remote_configs document.');
    } else {
      log.warning('Remote config document not found. Skipping migration.');
    }

    log.info('Migration RefactorUserPreferencesAndRemoteConfig.up completed.');
  }

  @override
  Future<void> down(Db db, Logger log) async {
    log.warning(
      'Executing "down" for RefactorUserPreferencesAndRemoteConfig. '
      'This is a destructive operation and may result in data loss.',
    );

    // --- 1. Revert user_content_preferences ---
    final preferencesCollection = db.collection('user_content_preferences');
    await preferencesCollection.updateMany(
      where.exists('savedHeadlineFilters'), // Target documents to revert
      modify
          .unset('savedHeadlineFilters')
          .unset('savedSourceFilters')
          .set('interests', <dynamic>[]),
    );
    log.info(
      'Reverted user_content_preferences: removed new filter fields and '
      're-added empty "interests" field.',
    );

    // --- 2. Revert remote_configs ---
    // This is a best-effort revert and will not restore the exact previous
    // state but will remove the new fields.
    final remoteConfigCollection = db.collection('remote_configs');
    await remoteConfigCollection.updateMany(
      where.exists('userPreferenceConfig.followedItemsLimit'),
      modify
          .unset('userPreferenceConfig')
          .set('interestConfig', <String, dynamic>{}),
    );
    log.info(
      'Reverted remote_configs: removed new userPreferenceConfig structure.',
    );

    log.info(
      'Migration RefactorUserPreferencesAndRemoteConfig.down completed.',
    );
  }
}
