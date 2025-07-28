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
    await _seedInitialAdminUser();

    await _seedCollection<Country>(
      collectionName: 'countries',
      fixtureData: countriesFixturesData,
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );
    await _seedCollection<Source>(
      collectionName: 'sources',
      fixtureData: sourcesFixturesData,
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );
    await _seedCollection<Topic>(
      collectionName: 'topics',
      fixtureData: topicsFixturesData,
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );
    await _seedCollection<Headline>(
      collectionName: 'headlines',
      fixtureData: headlinesFixturesData,
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );
    await _seedCollection<User>(
      collectionName: 'users',
      fixtureData: usersFixturesData,
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );
    await _seedCollection<UserAppSettings>(
      collectionName: 'user_app_settings',
      fixtureData: userAppSettingsFixturesData,
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );

    await _seedCollection<RemoteConfig>(
      collectionName: 'remote_configs',
      fixtureData: remoteConfigsFixturesData,
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );

    _log.info('Database seeding process completed.');
  }

  /// Seeds the initial administrator user from the environment variable.
  Future<void> _seedInitialAdminUser() async {
    _log.info('Checking for initial admin user...');
    final adminEmail = EnvironmentConfig.initialAdminEmail;

    if (adminEmail == null || adminEmail.isEmpty) {
      _log.info('INITIAL_ADMIN_EMAIL not set. Skipping admin user seeding.');
      return;
    }

    final usersCollection = _db.collection('users');
    final existingAdmin = await usersCollection.findOne({'email': adminEmail});

    if (existingAdmin != null) {
      _log.info('Admin user with email $adminEmail already exists.');
      return;
    }

    _log.info('Creating initial admin user for email: $adminEmail');
    final adminId = ObjectId();
    final adminUser = User(
      id: adminId.oid,
      email: adminEmail,
      appRole: AppUserRole.standardUser, // Admins are standard app users
      dashboardRole: DashboardUserRole.admin, // With admin dashboard role
      createdAt: DateTime.now(),
      feedActionStatus: Map.fromEntries(
        FeedActionType.values.map(
          (type) =>
              MapEntry(type, const UserFeedActionStatus(isCompleted: false)),
        ),
      ),
    );

    await usersCollection.insertOne(
      {'_id': adminId, ...adminUser.toJson()..remove('id')},
    );

    // Also create their default settings and preferences documents
    final defaultAppSettings = UserAppSettings(
      id: adminId.oid,
      displaySettings: const DisplaySettings(
        baseTheme: AppBaseTheme.system,
        accentTheme: AppAccentTheme.defaultBlue,
        fontFamily: 'SystemDefault',
        textScaleFactor: AppTextScaleFactor.medium,
        fontWeight: AppFontWeight.regular,
      ),
      language: 'en',
      feedPreferences: const FeedDisplayPreferences(
        headlineDensity: HeadlineDensity.standard,
        headlineImageStyle: HeadlineImageStyle.largeThumbnail,
        showSourceInHeadlineFeed: true,
        showPublishDateInHeadlineFeed: true,
      ),
    );

    await _db.collection('user_app_settings').insertOne(
      {'_id': adminId, ...defaultAppSettings.toJson()..remove('id')},
    );

    final defaultUserPreferences = UserContentPreferences(
      id: adminId.oid,
      followedCountries: const [],
      followedSources: const [],
      followedTopics: const [],
      savedHeadlines: const [],
    );

    await _db.collection('user_content_preferences').insertOne(
      {'_id': adminId, ...defaultUserPreferences.toJson()..remove('id')},
    );

    _log.info('Successfully created initial admin user for $adminEmail.');
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
            'update': {r'$set': document},
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

  /// Ensures that the necessary indexes exist on the collections.
  ///
  /// This method is idempotent; it will only create indexes if they do not
  /// already exist. It's crucial for enabling efficient text searches.
  Future<void> _ensureIndexes() async {
    _log.info('Ensuring database indexes exist...');
    try {
      // Text index for searching headlines by title
      await _db
          .collection('headlines')
          .createIndex(keys: {'title': 'text'}, name: 'headlines_text_index');

      // Text index for searching topics by name
      await _db
          .collection('topics')
          .createIndex(keys: {'name': 'text'}, name: 'topics_text_index');

      // Text index for searching sources by name
      await _db
          .collection('sources')
          .createIndex(keys: {'name': 'text'}, name: 'sources_text_index');

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
}
