import 'package:ht_shared/ht_shared.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template database_seeding_service}
/// A service responsible for seeding the MongoDB database with initial data.
///
/// This service reads data from predefined fixture lists in `ht_shared` and
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
    await _seedCollection<RemoteConfig>(
      collectionName: 'remote_configs',
      fixtureData: remoteConfigsFixturesData,
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
        // Generate a new ObjectId for each document
        final objectId = ObjectId();
        final document = toJson(item)..remove('id');

        operations.add({
          'replaceOne': {
            'filter': {}, // Match all documents (replace existing or insert new)
            'replacement': document,
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
}
