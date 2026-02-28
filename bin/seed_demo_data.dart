import 'dart:io';

import 'package:core/core.dart';
import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// A standalone script to seed the database with high-fidelity demo data.
///
/// Usage:
/// dart bin/seed_demo_data.dart
///
/// This script is designed to be run manually by a developer or admin.
/// It connects directly to the MongoDB instance defined in the .env file,
/// populates the collections with fixture data, and then exits.
///
/// It uses `upsert` operations to be idempotent (safe to run multiple times).
Future<void> main() async {
  // 1. Initialize Logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  final log = Logger('DemoDataSeeder');

  log.info('Starting Demo Data Seeding Process...');

  // 2. Load Configuration
  final env = DotEnv(includePlatformEnvironment: true)..load();
  final dbUrl = env['DATABASE_URL'];

  if (dbUrl == null || dbUrl.isEmpty) {
    log.severe('DATABASE_URL not found in .env file.');
    exit(1);
  }

  // 3. Connect to Database
  final db = Db(dbUrl);
  try {
    await db.open();
    log.info('Connected to MongoDB.');

    // 4. Execute Seeding Routines

    // --- Content Graph ---
    await _seedCollection<Topic>(
      db: db,
      log: log,
      collectionName: 'topics',
      items: getTopicsFixturesData(),
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );

    await _seedCollection<Source>(
      db: db,
      log: log,
      collectionName: 'sources',
      items: getSourcesFixturesData(),
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );

    await _seedCollection<Headline>(
      db: db,
      log: log,
      collectionName: 'headlines',
      items: getHeadlinesFixturesData(),
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );

    // --- Social & Moderation ---
    await _seedCollection<Engagement>(
      db: db,
      log: log,
      collectionName: 'engagements',
      items: getEngagementsFixturesData(),
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );

    await _seedCollection<Report>(
      db: db,
      log: log,
      collectionName: 'reports',
      items: getReportsFixturesData(),
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );

    await _seedCollection<AppReview>(
      db: db,
      log: log,
      collectionName: 'app_reviews',
      items: getAppReviewsFixturesData(),
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );

    // --- Analytics Dashboard Data ---
    // Note: These fixtures populate the "Admin Dashboard" with realistic looking
    // charts and metrics so you don't look at empty screens.
    await _seedCollection<KpiCardData>(
      db: db,
      log: log,
      collectionName: 'kpi_card_data',
      items: getKpiCardsFixturesData(),
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );

    await _seedCollection<ChartCardData>(
      db: db,
      log: log,
      collectionName: 'chart_card_data',
      items: getChartCardsFixturesData(),
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );

    await _seedCollection<RankedListCardData>(
      db: db,
      log: log,
      collectionName: 'ranked_list_card_data',
      items: getRankedListCardsFixturesData(),
      getId: (item) => item.id,
      toJson: (item) => item.toJson(),
    );

    log.info('------------------------------------------------');
    log.info('✅ Demo Data Seeding Completed Successfully.');
    log.info('------------------------------------------------');
  } catch (e, s) {
    log.severe('❌ Seeding Failed.', e, s);
    exit(1);
  } finally {
    await db.close();
    log.info('Database connection closed.');
  }
}

/// Generic helper to seed a list of items into a MongoDB collection.
///
/// Uses `bulkWrite` with `updateOne` + `upsert: true` for performance and
/// idempotency.
Future<void> _seedCollection<T>({
  required Db db,
  required Logger log,
  required String collectionName,
  required List<T> items,
  required String Function(T) getId,
  required Map<String, dynamic> Function(T) toJson,
}) async {
  if (items.isEmpty) {
    log.warning('No items to seed for collection: $collectionName');
    return;
  }

  log.info('Seeding $collectionName (${items.length} items)...');

  final collection = db.collection(collectionName);
  final operations = <Map<String, Object>>[];

  for (final item in items) {
    final idString = getId(item);

    // Ensure the ID is a valid MongoDB ObjectId hex string
    if (!ObjectId.isValidHexId(idString)) {
      log.warning('Skipping item with invalid hex ID: $idString');
      continue;
    }

    final objectId = ObjectId.fromHexString(idString);
    final doc = toJson(item);

    // Remove the string 'id' field as we use '_id' in Mongo
    doc.remove('id');

    // Handle the special 'language' field renaming if necessary
    // (Matches logic in DataMongodb)
    if (doc.containsKey('language')) {
      doc['modelLanguage'] = doc.remove('language');
    }

    operations.add({
      'updateOne': {
        'filter': {'_id': objectId},
        'update': {r'$set': doc},
        'upsert': true,
      },
    });
  }

  if (operations.isNotEmpty) {
    final result = await collection.bulkWrite(operations);
    log.info(
      '  -> Upserted: ${result.nUpserted}, Modified: ${result.nModified}, Matched: ${result.nMatched}',
    );
  }
}

// --- Mock Fixture Accessors ---
// In a real scenario, these would be imported from `package:core`.
// Based on the context provided, we assume these functions exist in the core package.
// If they are not exported, you would need to export them from `core.dart`.
//
// For this script to compile with the provided context, we assume `package:core/core.dart`
// exports these functions.
//
// If they are missing, you simply need to add the exports to `core.dart`.
