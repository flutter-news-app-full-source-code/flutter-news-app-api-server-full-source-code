import 'package:flutter_news_app_api_server_full_source_code/src/database/migration.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Migration to add the `savedFiltersLimit` fields to existing
/// `remote_configs` documents within the `userPreferenceConfig` sub-document.
class AddSavedFiltersToRemoteConfig extends Migration {
  /// {@macro add_saved_filters_to_remote_config}
  AddSavedFiltersToRemoteConfig()
    : super(
        prDate: '20251013000057',
        prId: '57',
        prSummary:
            'This pull request introduces the ability for users to save and manage custom filter combinations for news headlines. It achieves this by adding a new SavedFilter data model, integrating it into the existing user content preferences, and implementing configurable limits for these saved filters based on user tiers',
      );

  @override
  Future<void> up(Db db, Logger log) async {
    final collection = db.collection('remote_configs');
    final result = await collection.updateMany(
      // Filter for documents where 'userPreferenceConfig.guestSavedFiltersLimit' does not exist.
      // This assumes if one is missing, all are likely missing.
      where.notExists('userPreferenceConfig.guestSavedFiltersLimit'),
      // Set 'guestSavedFiltersLimit', 'authenticatedSavedFiltersLimit',
      // and 'premiumSavedFiltersLimit' to a default value.
      modify
          .set('userPreferenceConfig.guestSavedFiltersLimit', 3)
          .set('userPreferenceConfig.authenticatedSavedFiltersLimit', 10)
          .set('userPreferenceConfig.premiumSavedFiltersLimit', 25),
    );
    log.info(
      'Updated ${result.nModified} documents in remote_configs '
      'to include savedFiltersLimit fields.',
    );
  }

  @override
  Future<void> down(Db db, Logger log) async {
    final collection = db.collection('remote_configs');
    await collection.updateMany(
      where.exists('userPreferenceConfig.guestSavedFiltersLimit'),
      modify
          .unset('userPreferenceConfig.guestSavedFiltersLimit')
          .unset('userPreferenceConfig.authenticatedSavedFiltersLimit')
          .unset('userPreferenceConfig.premiumSavedFiltersLimit'),
    );
    log.info(
      'Removed "savedFiltersLimit" fields from remote_configs '
      'userPreferenceConfig sub-document.',
    );
  }
}
