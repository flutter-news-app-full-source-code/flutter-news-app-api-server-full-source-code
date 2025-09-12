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
    await _seedCollection<LocalAd>(
      collectionName: 'local_ads',
      fixtureData: localAdsFixturesData,
      getId: (ad) => ad.id,
      // ignore: unnecessary_lambdas
      toJson: (item) => LocalAd.toJson(item),
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

      final existingConfig = await remoteConfigCollection.findOne(
        where.id(objectId),
      );

      if (existingConfig == null) {
        _log.info('No existing RemoteConfig found. Creating initial config.');
        // Take the default from fixtures
        final initialConfig = remoteConfigsFixturesData.first;

        // Ensure primaryAdPlatform is not 'demo' for initial setup
        // sic its not intended for any use outside teh mobile client code.
        final productionReadyAdConfig = initialConfig.adConfig.copyWith(
          primaryAdPlatform: AdPlatformType.local,
        );

        final productionReadyConfig = initialConfig.copyWith(
          adConfig: productionReadyAdConfig,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await remoteConfigCollection.insertOne({
          '_id': objectId,
          ...productionReadyConfig.toJson()..remove('id'),
        });
        _log.info('Initial RemoteConfig created successfully.');
      } else {
        _log.info('RemoteConfig already exists. Skipping creation.');
      }
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
      /// Text index for searching headlines by title.
      /// This index supports efficient full-text search queries on the 'title' field
      /// of headline documents, crucial for the main search functionality.
      await _db
          .collection('headlines')
          .createIndex(keys: {'title': 'text'}, name: 'headlines_text_index');

      /// Text index for searching topics by name.
      /// This index enables efficient full-text search on the 'name' field of
      /// topic documents, used for searching topics.
      await _db
          .collection('topics')
          .createIndex(keys: {'name': 'text'}, name: 'topics_text_index');

      /// Text index for searching sources by name.
      /// This index facilitates efficient full-text search on the 'name' field of
      /// source documents, used for searching sources.
      await _db
          .collection('sources')
          .createIndex(keys: {'name': 'text'}, name: 'sources_text_index');

      /// Index for searching countries by name.
      /// This index supports efficient queries and sorting on the 'name' field
      /// of country documents, particularly for direct country searches.
      await _db
          .collection('countries')
          .createIndex(keys: {'name': 1}, name: 'countries_name_index');

      /// Index for searching local ads by adType.
      /// This index supports efficient queries and filtering on the 'adType' field
      /// of local ad documents.
      await _db
          .collection('local_ads')
          .createIndex(keys: {'adType': 1}, name: 'local_ads_adType_index');

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

      _log.info('Database indexes are set up correctly.');
    } on Exception catch (e, s) {
      _log.severe('Failed to create database indexes.', e, s);
      // We rethrow here because if indexes can't be created,
      // critical features like search will fail.
      rethrow;
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
      where.eq('dashboardRole', DashboardUserRole.admin.name),
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
      appRole: AppUserRole.standardUser,
      dashboardRole: DashboardUserRole.admin,
      createdAt: DateTime.now(),
      feedDecoratorStatus: Map.fromEntries(
        FeedDecoratorType.values.map(
          (type) =>
              MapEntry(type, const UserFeedDecoratorStatus(isCompleted: false)),
        ),
      ),
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
    await _db
        .collection('user_app_settings')
        .deleteOne(where.eq('_id', userId));
    await _db
        .collection('user_content_preferences')
        .deleteOne(where.eq('_id', userId));
    _log.info('Deleted user and associated data for ID: ${userId.oid}');
  }

  /// Creates the default sub-documents (settings, preferences) for a new user.
  Future<void> _createUserSubDocuments(ObjectId userId) async {
    final defaultAppSettings = UserAppSettings(
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
      feedPreferences: const FeedDisplayPreferences(
        headlineDensity: HeadlineDensity.standard,
        headlineImageStyle: HeadlineImageStyle.smallThumbnail,
        showSourceInHeadlineFeed: true,
        showPublishDateInHeadlineFeed: true,
      ),
    );
    await _db.collection('user_app_settings').insertOne({
      '_id': userId,
      ...defaultAppSettings.toJson()..remove('id'),
    });

    final defaultUserPreferences = UserContentPreferences(
      id: userId.oid,
      followedCountries: const [],
      followedSources: const [],
      followedTopics: const [],
      savedHeadlines: const [],
    );
    await _db.collection('user_content_preferences').insertOne({
      '_id': userId,
      ...defaultUserPreferences.toJson()..remove('id'),
    });
  }
}
