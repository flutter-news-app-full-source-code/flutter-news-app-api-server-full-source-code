import 'dart:convert';
import 'dart:io';

import 'package:ht_shared/ht_shared.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template database_seeding_service}
/// A service responsible for seeding the MongoDB database with initial data.
///
/// This service reads data from local JSON fixture files and uses `upsert`
/// operations to ensure that the seeding process is idempotent. It can be
/// run multiple times without creating duplicate documents.
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
    await _seedCollection(
      collectionName: 'countries',
      fixturePath: 'lib/src/fixtures/countries.json',
    );
    await _seedCollection(
      collectionName: 'sources',
      fixturePath: 'lib/src/fixtures/sources.json',
    );
    await _seedCollection(
      collectionName: 'topics',
      fixturePath: 'lib/src/fixtures/topics.json',
    );
    await _seedCollection(
      collectionName: 'headlines',
      fixturePath: 'lib/src/fixtures/headlines.json',
    );
    await _seedInitialAdminAndConfig();
    _log.info('Database seeding process completed.');
  }

  /// Seeds a specific collection from a given JSON fixture file.
  Future<void> _seedCollection({
    required String collectionName,
    required String fixturePath,
  }) async {
    _log.info('Seeding collection: "$collectionName" from "$fixturePath"...');
    try {
      final collection = _db.collection(collectionName);
      final file = File(fixturePath);
      if (!await file.exists()) {
        _log.warning('Fixture file not found: $fixturePath. Skipping.');
        return;
      }

      final content = await file.readAsString();
      final documents = jsonDecode(content) as List<dynamic>;

      if (documents.isEmpty) {
        _log.info('No documents to seed for "$collectionName".');
        return;
      }

      final bulk = collection.initializeUnorderedBulkOperation();

      for (final doc in documents) {
        final docMap = doc as Map<String, dynamic>;
        final id = docMap['id'] as String?;

        if (id == null || !ObjectId.isValidHexId(id)) {
          _log.warning('Skipping document with invalid or missing ID: $doc');
          continue;
        }

        final objectId = ObjectId.fromHexString(id);
        // Remove the string 'id' field and use '_id' with ObjectId
        docMap.remove('id');

        bulk.find({'_id': objectId}).upsert().replaceOne(docMap);
      }

      final result = await bulk.execute();
      _log.info(
        'Seeding for "$collectionName" complete. '
        'Upserted: ${result.nUpserted}, Modified: ${result.nModified}.',
      );
    } on Exception catch (e, s) {
      _log.severe(
        'Failed to seed collection "$collectionName" from "$fixturePath".',
        e,
        s,
      );
      // Re-throwing to halt the startup process if seeding fails.
      rethrow;
    }
  }

  /// Seeds the initial admin user and remote config document.
  Future<void> _seedInitialAdminAndConfig() async {
    _log.info('Seeding initial admin user and remote config...');
    try {
      // --- Seed Admin User ---
      final usersCollection = _db.collection('users');
      final adminUser = User.fromJson(adminUserFixture);
      final adminDoc = adminUser.toJson()
        ..['app_role'] = adminUser.appRole.name
        ..['dashboard_role'] = adminUser.dashboardRole.name
        ..['feed_action_status'] = jsonEncode(adminUser.feedActionStatus)
        ..remove('id');

      await usersCollection.updateOne(
        where.id(ObjectId.fromHexString(adminUser.id)),
        modify.set(
          'email',
          adminDoc['email'],
        ).setAll(adminDoc), // Use setAll to add/update all fields
        upsert: true,
      );
      _log.info('Admin user seeded successfully.');

      // --- Seed Remote Config ---
      final remoteConfigCollection = _db.collection('remote_config');
      final remoteConfig = RemoteConfig.fromJson(remoteConfigFixture);
      final remoteConfigDoc = remoteConfig.toJson()
        ..['user_preference_limits'] =
            jsonEncode(remoteConfig.userPreferenceConfig.toJson())
        ..['ad_config'] = jsonEncode(remoteConfig.adConfig.toJson())
        ..['account_action_config'] =
            jsonEncode(remoteConfig.accountActionConfig.toJson())
        ..['app_status'] = jsonEncode(remoteConfig.appStatus.toJson())
        ..remove('id');

      await remoteConfigCollection.updateOne(
        where.id(ObjectId.fromHexString(remoteConfig.id)),
        modify.setAll(remoteConfigDoc),
        upsert: true,
      );
      _log.info('Remote config seeded successfully.');
    } on Exception catch (e, s) {
      _log.severe('Failed to seed admin user or remote config.', e, s);
      rethrow;
    }
  }
}