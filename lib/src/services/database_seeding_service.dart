import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/mongodb_token_blacklist_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/mongodb_verification_code_storage_service.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template database_seeding_service}
/// A service responsible for seeding the MongoDB database with initial data.
///
/// This service reads data from predefined fixture lists in `core` and
/// uses `upsert` operations to ensure that the seeding process is idempotent.
/// It can be run multiple times without creating duplicate documents.
/// {@endtemplate}
class DatabaseSeedingService {
  /// {@macro database_seeding_service}
  const DatabaseSeedingService({required Db db, required Logger log})
    : _db = db,
      _log = log;

  final Db _db;
  final Logger _log;

  /// The main entry point for seeding all necessary data.
  Future<void> seedInitialData() async {
    _log.info('Starting database seeding process...');

    await _ensureIndexes();
    await _seedOverrideAdminUser();
    await _seedRemoteConfig();
    await _seedCollection<Country>(
      collectionName: 'countries',
      fixtureData: countriesFixturesData,
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );
    await _seedCollection<Language>(
      collectionName: 'languages',
      fixtureData: languagesFixturesData,
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );

    _log.info('Database seeding process completed.');
  }

  /// Seeds a specific collection from a given list of fixture data.
  Future<void> _seedCollection<T>({
    required String collectionName,
    required List<T> fixtureData,
    required String Function(T) getId,
    required Map<String, dynamic> Function(T) toJson,
  }) async {
    _log.info('Seeding collection: "$collectionName"...');
    try {
      if (fixtureData.isEmpty) {
        _log.info('No documents to seed for "$collectionName".');
        return;
      }

      final collection = _db.collection(collectionName);
      final operations = <Map<String, Object>>[];

      for (final item in fixtureData) {
        // Use the predefined hex string ID from the fixture to create a
        // deterministic ObjectId. This is crucial for maintaining relationships
        // between documents (e.g., a headline and its source).
        final objectId = ObjectId.fromHexString(getId(item));
        final document = toJson(item)..remove('id');

        operations.add({
          // Use updateOne with $set to be less destructive than replaceOne.
          'updateOne': {
            // Filter by the specific, deterministic _id.
            'filter': {'_id': objectId},
            // Set the fields of the document.
            // Use $setOnInsert to set fields ONLY if the document is newly inserted.
            // This ensures existing documents are not overwritten by fixture data.
            'update': {r'$setOnInsert': document},
            'upsert': true,
          },
        });
      }

      final result = await collection.bulkWrite(operations);
      _log.info(
        'Seeding for "$collectionName" complete. '
        'Upserted: ${result.nUpserted}, Modified: ${result.nModified}.',
      );
    } on Exception catch (e, s) {
      _log.severe('Failed to seed collection "$collectionName".', e, s);
      rethrow;
    }
  }

  /// Ensures the initial RemoteConfig document exists and has
  /// a default for the primary ad platform, if not already set.
  ///
  /// This method only creates the document if it does not exist.
  /// It does NOT overwrite existing configurations.
  Future<void> _seedRemoteConfig() async {
    _log.info('Seeding RemoteConfig...');
    try {
      final remoteConfigCollection = _db.collection('remote_configs');
      if (remoteConfigsFixturesData.isEmpty) {
        _log.warning(
          'Remote config fixture data is empty. Skipping RemoteConfig seeding.',
        );
        return;
      }
      final defaultRemoteConfigId = remoteConfigsFixturesData.first.id;
      final objectId = ObjectId.fromHexString(defaultRemoteConfigId);

      // Start with the default configuration from the fixtures data.
      final initialConfig = remoteConfigsFixturesData.first;
      final featuresConfig = initialConfig.features;

      final productionReadyConfig = initialConfig.copyWith(
        features: featuresConfig,
        // Ensure timestamps are set for the initial creation.
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Use `updateOne` with `$setOnInsert` to create the document only if it
      // does not exist. This prevents overwriting an admin's custom changes
      // on subsequent server restarts.
      await remoteConfigCollection.updateOne(
        where.id(objectId),
        {r'$setOnInsert': productionReadyConfig.toJson()..remove('id')},
        upsert: true,
      );
      _log.info('Ensured RemoteConfig document exists and is sanitized.');
    } on Exception catch (e, s) {
      _log.severe('Failed to seed RemoteConfig.', e, s);
      rethrow;
    }
  }

  /// Ensures that the necessary indexes exist on the collections.
  ///
  /// This method is idempotent; it will only create indexes if they do not
  /// already exist. It's crucial for enabling efficient text searches.
  Future<void> _ensureIndexes() async {
    _log.info('Ensuring database indexes exist...');
    try {
      /// Index for searching countries by name.
      /// This index supports efficient queries and sorting on the 'name' field
      /// of country documents, particularly for direct country searches.
      await _db
          .collection('countries')
          .createIndex(keys: {'name': 1}, name: 'countries_name_index');

      // --- TTL and Unique Indexes via runCommand ---
      // The following indexes are created using the generic `runCommand` because
      // they require specific options not exposed by the simpler `createIndex`
      // helper method in the `mongo_dart` library.
      // Specifically, `expireAfterSeconds` is needed for TTL indexes.

      // Indexes for the verification codes collection
      await _db.runCommand({
        'createIndexes': kVerificationCodesCollection,
        'indexes': [
          {
            // This is a TTL (Time-To-Live) index. MongoDB will automatically
            // delete documents from this collection when the `expiresAt` field's
            // value is older than the specified number of seconds (0).
            'key': {'expiresAt': 1},
            'name': 'expiresAt_ttl_index',
            'expireAfterSeconds': 0,
          },
          {
            // This ensures that each email can only have one pending
            // verification code at a time, preventing duplicates.
            'key': {'email': 1},
            'name': 'email_unique_index',
            'unique': true,
          },
        ],
      });

      // Index for the token blacklist collection
      await _db.runCommand({
        'createIndexes': kBlacklistedTokensCollection,
        'indexes': [
          {
            // This is a TTL index. MongoDB will automatically delete documents
            // (blacklisted tokens) when the `expiry` field's value is past.
            'key': {'expiry': 1},
            'name': 'expiry_ttl_index',
            'expireAfterSeconds': 0,
          },
        ],
      });

      // Indexes for the push notification devices collection
      await _db.runCommand({
        'createIndexes': 'push_notification_devices',
        'indexes': [
          {
            // Ensures no two devices can have the same Firebase token.
            // The index is sparse, so it only applies to documents that
            // actually have a 'providerTokens.firebase' field.
            'key': {'providerTokens.firebase': 1},
            'name': 'firebase_token_unique_sparse_index',
            'unique': true,
            'sparse': true,
          },
          {
            // Ensures no two devices can have the same OneSignal token.
            // The index is sparse, so it only applies to documents that
            // actually have a 'providerTokens.oneSignal' field.
            'key': {'providerTokens.oneSignal': 1},
            'name': 'oneSignal_token_unique_sparse_index',
            'unique': true,
            'sparse': true,
          },
          {
            // Optimizes fetching all devices for a specific user, which is
            // needed for the device cleanup flow on the client.
            'key': {'userId': 1},
            'name': 'userId_index',
          },
        ],
      });
      await _db.runCommand({
        'createIndexes': 'user_content_preferences',
        'indexes': [
          {
            'key': {'savedHeadlineFilters.deliveryTypes': 1},
            'name': 'breaking_news_subscription_index',
          },
        ],
      });
      _log.info('Ensured indexes for "push_notification_devices".');

      // Indexes for the in-app notifications collection
      await _db.runCommand({
        'createIndexes': 'in_app_notifications',
        'indexes': [
          {
            // Optimizes fetching notifications for a specific user.
            'key': {'userId': 1},
            'name': 'userId_index',
          },
          {
            // This is a TTL (Time-To-Live) index. MongoDB will automatically
            // delete documents from this collection when the `createdAt`
            // field's value is older than the specified number of seconds.
            'key': {'createdAt': 1},
            'name': 'createdAt_ttl_index',
            'expireAfterSeconds': 7776000, // 90 days
          },
        ],
      });
      _log.info('Ensured indexes for "in_app_notifications".');

      // Indexes for the engagements collection
      await _db.runCommand({
        'createIndexes': 'engagements',
        'indexes': [
          {
            // Optimizes fetching all engagements for a specific user.
            'key': {'userId': 1},
            'name': 'userId_index',
          },
          {
            // Optimizes fetching all engagements for a specific entity
            // (e.g., a headline).
            'key': {'entityId': 1, 'entityType': 1},
            'name': 'entity_index',
          },
        ],
      });
      _log.info('Ensured indexes for "engagements".');

      // Indexes for the reports collection
      await _db.runCommand({
        'createIndexes': 'reports',
        'indexes': [
          {
            // Optimizes fetching all reports submitted by a specific user.
            'key': {'reporterUserId': 1},
            'name': 'reporterUserId_index',
          },
        ],
      });
      _log.info('Ensured indexes for "reports".');

      // Indexes for the app_reviews collection
      await _db.runCommand({
        'createIndexes': 'app_reviews',
        'indexes': [
          {
            // Optimizes fetching the review record for a specific user.
            'key': {'userId': 1},
            'name': 'userId_index',
          },
        ],
      });
      _log.info('Ensured indexes for "app_reviews".');

      // Indexes for the user_contexts collection
      await _db.runCommand({
        'createIndexes': 'user_contexts',
        'indexes': [
          {
            'key': {'userId': 1},
            'name': 'userId_index',
            'unique': true,
          },
        ],
      });
      _log.info('Ensured indexes for "user_contexts".');

      // Indexes for the user_rewards collection
      await _db.runCommand({
        'createIndexes': 'user_rewards',
        'indexes': [
          {
            'key': {'userId': 1},
            'name': 'userId_index',
          },
        ],
      });
      _log.info('Ensured indexes for "user_rewards".');

      // Indexes for the users collection
      await _db.runCommand({
        'createIndexes': 'users',
        'indexes': [
          {
            // For `users` collection aggregations (e.g., role distribution).
            'key': {'role': 1},
            'name': 'analytics_user_role_index',
          },
        ],
      });
      _log.info('Ensured analytics indexes for "users".');

      // Indexes for the reports collection
      await _db.runCommand({
        'createIndexes': 'reports',
        'indexes': [
          {
            // Optimizes fetching all reports submitted by a specific user.
            'key': {'reporterUserId': 1},
            'name': 'reporterUserId_index',
          },
          {
            // For `reports` collection aggregations (e.g., by reason).
            'key': {'createdAt': 1, 'reason': 1},
            'name': 'analytics_report_reason_index',
          },
          {
            // For `reports` collection aggregations (e.g., resolution time).
            'key': {'status': 1, 'updatedAt': 1},
            'name': 'analytics_report_resolution_index',
          },
        ],
      });
      _log.info('Ensured analytics indexes for "reports".');

      // Indexes for the engagements collection
      await _db.runCommand({
        'createIndexes': 'engagements',
        'indexes': [
          {
            // Optimizes fetching all engagements for a specific user.
            'key': {'userId': 1},
            'name': 'userId_index',
          },
          {
            // Optimizes fetching all engagements for a specific entity.
            'key': {'entityId': 1, 'entityType': 1},
            'name': 'entity_index',
          },
          {
            // For `engagements` collection aggregations (e.g., reactions by type).
            'key': {'createdAt': 1, 'reaction.reactionType': 1},
            'name': 'analytics_engagement_reaction_type_index',
          },
        ],
      });
      _log.info('Ensured analytics indexes for "engagements".');

      // Indexes for the headlines collection
      await _db.runCommand({
        'createIndexes': 'headlines',
        'indexes': [
          {
            'key': {'title': 'text'},
            'name': 'headlines_text_index',
          },
          {
            'key': {'createdAt': 1, 'topic.name': 1},
            'name': 'analytics_headline_topic_index',
          },
          {
            'key': {'createdAt': 1, 'source.name': 1},
            'name': 'analytics_headline_source_index',
          },
          {
            'key': {'createdAt': 1, 'isBreaking': 1},
            'name': 'analytics_headline_breaking_index',
          },
        ],
      });
      _log.info('Ensured analytics indexes for "headlines".');

      // Indexes for the sources collection
      await _db.runCommand({
        'createIndexes': 'sources',
        'indexes': [
          {
            'key': {'name': 'text'},
            'name': 'sources_text_index',
          },
          {
            'key': {'followerIds': 1},
            'name': 'analytics_source_followers_index',
          },
        ],
      });

      // Indexes for the topics collection
      await _db.runCommand({
        'createIndexes': 'topics',
        'indexes': [
          {
            'key': {'name': 'text'},
            'name': 'topics_text_index',
          },
          {
            'key': {'followerIds': 1},
            'name': 'analytics_topic_followers_index',
          },
        ],
      });

      // Indexes for the analytics card data collections.
      // Using runCommand to ensure no default 'unique' field is added, which
      // is invalid for an _id index. This also ensures the collections exist
      // on startup.
      await _db.runCommand({
        'createIndexes': 'kpi_card_data',
        'indexes': [
          {
            'key': {'_id': 1},
            'name': 'kpi_card_data_id_index',
          },
          {
            'key': {'cardId': 1},
            'name': 'kpi_card_data_cardId_index',
          },
        ],
      });
      _log.info('Ensured indexes for "kpi_card_data".');

      await _db.runCommand({
        'createIndexes': 'chart_card_data',
        'indexes': [
          {
            'key': {'_id': 1},
            'name': 'chart_card_data_id_index',
          },
          {
            'key': {'cardId': 1},
            'name': 'chart_card_data_cardId_index',
          },
        ],
      });
      _log.info('Ensured indexes for "chart_card_data".');

      await _db.runCommand({
        'createIndexes': 'ranked_list_card_data',
        'indexes': [
          {
            'key': {'_id': 1},
            'name': 'ranked_list_card_data_id_index',
          },
          {
            'key': {'cardId': 1},
            'name': 'ranked_list_card_data_cardId_index',
          },
        ],
      });
      _log.info('Ensured indexes for "ranked_list_card_data".');

      // Indexes for idempotency_records
      await _db.runCommand({
        'createIndexes': 'idempotency_records',
        'indexes': [
          {
            'key': {'createdAt': 1},
            'name': 'createdAt_ttl_index',
            'expireAfterSeconds': 86400 * 7, // 7 days retention
          },
        ],
      });
      _log.info('Ensured indexes for "idempotency_records".');

      // Indexes for media_assets
      await _db.runCommand({
        'createIndexes': 'media_assets',
        'indexes': [
          {
            'key': {'userId': 1},
            'name': 'userId_index',
          },
          {
            // Ensures that each file path in the bucket is unique.
            'key': {'storagePath': 1},
            'name': 'storagePath_unique_index',
            'unique': true,
          },
          {
            // Optimizes finding assets by their status, crucial for the
            // cleanup worker.
            'key': {'status': 1},
            'name': 'status_index',
          },
        ],
      });
      _log.info('Ensured indexes for "media_assets".');

      // Indexes for local_upload_tokens
      await _db.runCommand({
        'createIndexes': 'local_upload_tokens',
        'indexes': [
          {
            // This is a TTL index. MongoDB will automatically delete documents
            // (upload tokens) 15 minutes after they are created.
            'key': {'createdAt': 1},
            'name': 'createdAt_ttl_index',
            'expireAfterSeconds': 900, // 15 minutes
          },
        ],
      });
      _log.info('Ensured indexes for "local_upload_tokens".');

      // Indexes for local_media_finalization_jobs
      await _db.runCommand({
        'createIndexes': 'local_media_finalization_jobs',
        'indexes': [
          {
            // This is a TTL index. MongoDB will automatically delete jobs
            // that haven't been processed within 24 hours.
            'key': {'createdAt': 1},
            'name': 'createdAt_ttl_index',
            'expireAfterSeconds': 86400, // 24 hours
          },
        ],
      });
      _log.info('Ensured indexes for "local_media_finalization_jobs".');

      _log.info('Database indexes are set up correctly.');
    } on Exception catch (e, s) {
      _log.severe('Failed to create database indexes.', e, s);
      // We rethrow here because if indexes can't be created,
      // critical features like search will fail.
      rethrow;
    }

    // --- Indexes for Orphaned Media Cleanup ---
    // These indexes are crucial for the performance of the media cleanup worker.
    try {
      await _db.runCommand({
        'createIndexes': 'users',
        'indexes': [
          {
            'key': {'mediaAssetId': 1},
            'name': 'mediaAssetId_sparse_index',
            'sparse': true,
          },
        ],
      });
      await _db.runCommand({
        'createIndexes': 'headlines',
        'indexes': [
          {
            'key': {'mediaAssetId': 1},
            'name': 'mediaAssetId_sparse_index',
            'sparse': true,
          },
        ],
      });
      await _db.runCommand({
        'createIndexes': 'topics',
        'indexes': [
          {
            'key': {'mediaAssetId': 1},
            'name': 'mediaAssetId_sparse_index',
            'sparse': true,
          },
        ],
      });
      await _db.runCommand({
        'createIndexes': 'sources',
        'indexes': [
          {
            'key': {'mediaAssetId': 1},
            'name': 'mediaAssetId_sparse_index',
            'sparse': true,
          },
        ],
      });
      _log.info('Ensured sparse indexes for mediaAssetId references.');
    } on Exception catch (e, s) {
      _log.severe('Failed to create mediaAssetId sparse indexes.', e, s);
    }
  }

  /// Ensures the single administrator account is correctly configured based on
  /// the `OVERRIDE_ADMIN_EMAIL` environment variable.
  Future<void> _seedOverrideAdminUser() async {
    _log.info('Checking for admin user override...');
    final overrideEmail = EnvironmentConfig.overrideAdminEmail;

    if (overrideEmail == null || overrideEmail.isEmpty) {
      _log.info('OVERRIDE_ADMIN_EMAIL not set. Skipping admin user override.');
      return;
    }

    final usersCollection = _db.collection('users');

    final existingAdmin = await usersCollection.findOne(
      where.eq('role', UserRole.admin.name),
    );

    // Case 1: An admin exists.
    if (existingAdmin != null) {
      final existingAdminEmail = existingAdmin['email'] as String;
      // If the existing admin's email is the same as the override, do nothing.
      if (existingAdminEmail == overrideEmail) {
        _log.info(
          'Admin user with email $overrideEmail already exists and matches '
          'override. No action needed.',
        );
        return;
      }

      // If emails differ, delete the old admin and their data.
      _log.warning(
        'Found existing admin with email "$existingAdminEmail". It will be '
        'replaced by the override email "$overrideEmail".',
      );
      final oldAdminId = existingAdmin['_id'] as ObjectId;
      await _deleteUserAndData(oldAdminId);
    }

    // Case 2: No admin exists, or the old one was just deleted.
    // Create the new admin.
    _log.info('Creating admin user for email: $overrideEmail');
    final newAdminId = ObjectId();
    final newAdminUser = User(
      id: newAdminId.oid,
      email: overrideEmail,
      isAnonymous: false,
      role: UserRole.admin,
      tier: AccessTier.standard,
      createdAt: DateTime.now(),
    );

    await usersCollection.insertOne({
      '_id': newAdminId,
      ...newAdminUser.toJson()..remove('id'),
    });

    // Create default settings and preferences for the new admin.
    await _createUserSubDocuments(newAdminId);

    _log.info('Successfully created admin user for $overrideEmail.');
  }

  /// Deletes a user and their associated sub-documents.
  Future<void> _deleteUserAndData(ObjectId userId) async {
    await _db.collection('users').deleteOne(where.eq('_id', userId));
    await _db.collection('app_settings').deleteOne(where.eq('_id', userId));
    await _db
        .collection('user_contexts')
        .deleteOne(where.eq('userId', userId.oid));
    await _db
        .collection('user_content_preferences')
        .deleteOne(where.eq('_id', userId));
    _log.info('Deleted user and associated data for ID: ${userId.oid}');
  }

  /// Creates the default sub-documents (settings, preferences) for a new user.
  Future<void> _createUserSubDocuments(ObjectId userId) async {
    final defaultAppSettings = AppSettings(
      id: userId.oid,
      displaySettings: const DisplaySettings(
        baseTheme: AppBaseTheme.system,
        accentTheme: AppAccentTheme.defaultBlue,
        fontFamily: 'SystemDefault',
        textScaleFactor: AppTextScaleFactor.medium,
        fontWeight: AppFontWeight.regular,
      ),
      language: languagesFixturesData.firstWhere(
        (l) => l.code == 'en',
        orElse: () => throw StateError(
          'Default language "en" not found in language fixtures.',
        ),
      ),
      feedSettings: const FeedSettings(
        feedItemDensity: FeedItemDensity.standard,
        feedItemImageStyle: FeedItemImageStyle.smallThumbnail,
        feedItemClickBehavior: FeedItemClickBehavior.internalNavigation,
      ),
    );
    await _db.collection('app_settings').insertOne({
      '_id': userId,
      ...defaultAppSettings.toJson()..remove('id'),
    });

    // Initialize with empty lists for all user-managed content.
    final defaultUserPreferences = UserContentPreferences(
      id: userId.oid,
      followedCountries: const [],
      followedSources: const [],
      followedTopics: const [],
      savedHeadlines: const [],
      savedHeadlineFilters: const [],
      savedSourceFilters: const [],
    );
    await _db.collection('user_content_preferences').insertOne({
      '_id': userId,
      ...defaultUserPreferences.toJson()..remove('id'),
    });

    // Create a default UserContext for the new user.
    final defaultUserContext = UserContext(
      id: userId.oid,
      userId: userId.oid,
      feedDecoratorStatus: Map.fromEntries(
        FeedDecoratorType.values.map(
          (type) =>
              MapEntry(type, const UserFeedDecoratorStatus(isCompleted: false)),
        ),
      ),
    );
    await _db.collection('user_contexts').insertOne({
      '_id': ObjectId.fromHexString(defaultUserContext.id),
      ...defaultUserContext.toJson()..remove('id'),
    });
  }
}
