import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/database/migration.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template unify_interests_and_remote_config}
/// A migration to refactor the database schema by unifying `SavedFilter` and
/// `PushNotificationSubscription` into a single `Interest` model.
///
/// This migration performs two critical transformations:
///
/// 1.  **User Preferences Transformation:** It iterates through all
///     `user_content_preferences` documents. For each user, it reads the
///     legacy `savedFilters` and `notificationSubscriptions` arrays, converts
///     them into the new `Interest` format, and merges them. It then saves
///     this new list to an `interests` field and removes the old, obsolete
///     arrays.
///
/// 2.  **Remote Config Transformation:** It updates the single `remote_configs`
///     document by adding the new `interestConfig` field with default limits
///     and removing the now-deprecated limit fields from `userPreferenceConfig`
///     and `pushNotificationConfig`.
/// {@endtemplate}
class UnifyInterestsAndRemoteConfig extends Migration {
  /// {@macro unify_interests_and_remote_config}
  UnifyInterestsAndRemoteConfig()
    : super(
        prDate: '20251111000000',
        prId: '74',
        prSummary:
            'This pull request introduces a significant new Interest feature, designed to enhance user personalization by unifying content filtering and notification subscriptions.',
      );

  @override
  Future<void> up(Db db, Logger log) async {
    log.info('Starting migration: UnifyInterestsAndRemoteConfig.up');

    // --- 1. Migrate user_content_preferences ---
    log.info('Migrating user_content_preferences collection...');
    final preferencesCollection = db.collection('user_content_preferences');
    final allPreferences = await preferencesCollection.find().toList();

    for (final preferenceDoc in allPreferences) {
      final userId = (preferenceDoc['_id'] as ObjectId).oid;
      log.finer('Processing preferences for user: $userId');

      final savedFilters =
          (preferenceDoc['savedFilters'] as List<dynamic>? ?? [])
              .map((e) => e as Map<String, dynamic>)
              .toList();
      final notificationSubscriptions =
          (preferenceDoc['notificationSubscriptions'] as List<dynamic>? ?? [])
              .map((e) => e as Map<String, dynamic>)
              .toList();

      if (savedFilters.isEmpty && notificationSubscriptions.isEmpty) {
        log.finer('User $userId has no legacy data to migrate. Skipping.');
        continue;
      }

      // Use a map to merge filters and subscriptions with the same criteria.
      final interestMap = <String, Interest>{};

      // Process saved filters
      for (final filter in savedFilters) {
        final criteriaData = filter['criteria'];
        if (criteriaData is! Map<String, dynamic>) {
          log.warning(
            'User $userId has a malformed savedFilter with missing or invalid '
            '"criteria". Skipping this filter.',
          );
          continue;
        }

        final criteria = InterestCriteria.fromJson(criteriaData);
        final key = _generateCriteriaKey(criteria);

        interestMap.update(
          key,
          (existing) => existing.copyWith(isPinnedFeedFilter: true),
          ifAbsent: () => Interest(
            id: ObjectId().oid,
            userId: userId,
            name: filter['name'] as String,
            criteria: criteria,
            isPinnedFeedFilter: true,
            deliveryTypes: const {},
          ),
        );
      }

      // Process notification subscriptions
      for (final subscription in notificationSubscriptions) {
        final criteriaData = subscription['criteria'];
        if (criteriaData is! Map<String, dynamic>) {
          log.warning(
            'User $userId has a malformed notificationSubscription with '
            'missing or invalid "criteria". Skipping this subscription.',
          );
          continue;
        }

        final criteria = InterestCriteria.fromJson(criteriaData);
        final key = _generateCriteriaKey(criteria);
        final deliveryTypes =
            (subscription['deliveryTypes'] as List<dynamic>? ?? [])
                .map(
                  (e) => PushNotificationSubscriptionDeliveryType.values.byName(
                    e as String,
                  ),
                )
                .toSet();

        interestMap.update(
          key,
          (existing) => existing.copyWith(
            deliveryTypes: {...existing.deliveryTypes, ...deliveryTypes},
          ),
          ifAbsent: () => Interest(
            id: ObjectId().oid,
            userId: userId,
            name: subscription['name'] as String,
            criteria: criteria,
            isPinnedFeedFilter: false,
            deliveryTypes: deliveryTypes,
          ),
        );
      }

      final newInterests = interestMap.values.map((i) => i.toJson()).toList();

      await preferencesCollection.updateOne(
        where.id(preferenceDoc['_id'] as ObjectId),
        modify
            .set('interests', newInterests)
            .unset('savedFilters')
            .unset('notificationSubscriptions'),
      );
      log.info(
        'Successfully migrated ${newInterests.length} interests for user $userId.',
      );
    }

    // --- 2. Migrate remote_configs ---
    log.info('Migrating remote_configs collection...');
    final remoteConfigCollection = db.collection('remote_configs');
    final remoteConfig = await remoteConfigCollection.findOne();

    if (remoteConfig != null) {
      // Use the default from the core package fixtures as the base.
      final defaultConfig = remoteConfigsFixturesData.first.interestConfig;

      await remoteConfigCollection.updateOne(
        where.id(remoteConfig['_id'] as ObjectId),
        modify
            .set('interestConfig', defaultConfig.toJson())
            .unset('userPreferenceConfig.guestSavedFiltersLimit')
            .unset('userPreferenceConfig.authenticatedSavedFiltersLimit')
            .unset('userPreferenceConfig.premiumSavedFiltersLimit')
            .unset('pushNotificationConfig.deliveryConfigs'),
      );
      log.info('Successfully migrated remote_configs document.');
    } else {
      log.warning('Remote config document not found. Skipping migration.');
    }

    log.info('Migration UnifyInterestsAndRemoteConfig.up completed.');
  }

  @override
  Future<void> down(Db db, Logger log) async {
    log.warning(
      'Executing "down" for UnifyInterestsAndRemoteConfig. '
      'This is a destructive operation and may result in data loss.',
    );

    // --- 1. Revert user_content_preferences ---
    final preferencesCollection = db.collection('user_content_preferences');
    await preferencesCollection.updateMany(
      where.exists('interests'),
      modify
          .unset('interests')
          .set('savedFilters', <dynamic>[])
          .set('notificationSubscriptions', <dynamic>[]),
    );
    log.info(
      'Removed "interests" field and re-added empty legacy fields to all '
      'user_content_preferences documents.',
    );

    // --- 2. Revert remote_configs ---
    final remoteConfigCollection = db.collection('remote_configs');
    await remoteConfigCollection.updateMany(
      where.exists('interestConfig'),
      modify
          .unset('interestConfig')
          .set('userPreferenceConfig.guestSavedFiltersLimit', 5)
          .set('userPreferenceConfig.authenticatedSavedFiltersLimit', 20)
          .set('userPreferenceConfig.premiumSavedFiltersLimit', 50)
          .set(
            'pushNotificationConfig.deliveryConfigs',
            {
              'breakingOnly': true,
              'dailyDigest': true,
              'weeklyRoundup': true,
            },
          ),
    );
    log.info('Reverted remote_configs document to legacy structure.');

    log.info('Migration UnifyInterestsAndRemoteConfig.down completed.');
  }

  /// Generates a stable, sorted key from interest criteria to identify
  /// duplicates.
  String _generateCriteriaKey(InterestCriteria criteria) {
    final topics = criteria.topics.map((t) => t.id).toList()..sort();
    final sources = criteria.sources.map((s) => s.id).toList()..sort();
    final countries = criteria.countries.map((c) => c.id).toList()..sort();
    return 't:${topics.join(',')};s:${sources.join(',')};c:${countries.join(',')}';
  }
}
