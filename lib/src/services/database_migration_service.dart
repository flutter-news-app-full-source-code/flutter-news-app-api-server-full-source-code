import 'package:flutter_news_app_api_server_full_source_code/src/database/migration.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template database_migration_service}
/// A service responsible for managing and executing database migrations.
///
/// This service discovers, sorts, and applies pending [Migration] scripts
/// to the MongoDB database. It tracks applied migrations in a dedicated
/// `migrations_history` collection to ensure idempotency and prevent
/// redundant execution.
///
/// Migrations are identified by a unique version string (YYYYMMDDHHMMSS)
/// and are always applied in chronological order.
/// {@endtemplate}
class DatabaseMigrationService {
  /// {@macro database_migration_service}
  DatabaseMigrationService({
    required Db db,
    required Logger log,
    required List<Migration> migrations,
  })  : _db = db,
        _log = log,
        _migrations = migrations;

  final Db _db;
  final Logger _log;
  final List<Migration> _migrations;

  /// The name of the MongoDB collection used to track applied migrations.
  static const String _migrationsCollectionName = 'migrations_history';

  /// Initializes the migration service and applies any pending migrations.
  ///
  /// This method performs the following steps:
  /// 1. Ensures the `migrations_history` collection exists and has a unique
  ///    index on the `version` field.
  /// 2. Fetches all previously applied migration versions from the database.
  /// 3. Sorts the registered migrations by their version string.
  /// 4. Iterates through the sorted migrations, applying only those that
  ///    have not yet been applied.
  /// 5. Records each successfully applied migration in the `migrations_history`
  ///    collection.
  Future<void> init() async {
    _log.info('Starting database migration process...');

    await _ensureMigrationsCollectionAndIndex();

    final appliedVersions = await _getAppliedMigrationVersions();
    _log.fine('Applied migration versions: $appliedVersions');

    // Sort migrations by version to ensure chronological application.
    _migrations.sort((a, b) => a.version.compareTo(b.version));

    for (final migration in _migrations) {
      if (!appliedVersions.contains(migration.version)) {
        _log.info(
          'Applying migration V${migration.version}: ${migration.description}',
        );
        try {
          await migration.up(_db, _log);
          await _recordMigration(migration.version);
          _log.info(
            'Successfully applied migration V${migration.version}.',
          );
        } catch (e, s) {
          _log.severe(
            'Failed to apply migration V${migration.version}: '
            '${migration.description}',
            e,
            s,
          );
          // Re-throw to halt application startup if a migration fails.
          rethrow;
        }
      } else {
        _log.fine(
          'Migration V${migration.version} already applied. Skipping.',
        );
      }
    }

    _log.info('Database migration process completed.');
  }

  /// Ensures the `migrations_history` collection exists and has a unique index
  /// on the `version` field.
  Future<void> _ensureMigrationsCollectionAndIndex() async {
    _log.fine('Ensuring migrations_history collection and index...');
    final collection = _db.collection(_migrationsCollectionName);
    await collection.createIndex(
      key: 'version',
      unique: true,
      name: 'version_unique_index',
    );
    _log.fine('Migrations_history collection and index ensured.');
  }

  /// Retrieves a set of versions of all migrations that have already been
  /// applied to the database.
  Future<Set<String>> _getAppliedMigrationVersions() async {
    final collection = _db.collection(_migrationsCollectionName);
    final documents = await collection.find().toList();
    return documents
        .map((doc) => doc['version'] as String)
        .toSet();
  }

  /// Records a successfully applied migration in the `migrations_history`
  /// collection.
  Future<void> _recordMigration(String version) async {
    final collection = _db.collection(_migrationsCollectionName);
    await collection.insertOne({
      'version': version,
      'appliedAt': DateTime.now().toUtc(),
    });
  }
}
