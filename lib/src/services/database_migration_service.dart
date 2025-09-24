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
/// Migrations are identified by their PR merge date (YYYYMMDDHHMMSS)
/// and are always applied in chronological order.
/// {@endtemplate}
class DatabaseMigrationService {
  /// {@macro database_migration_service}
  DatabaseMigrationService({
    required Db db,
    required Logger log,
    required List<Migration> migrations,
  }) : _db = db,
       _log = log,
       _migrations = migrations;

  final Db _db;
  final Logger _log;
  final List<Migration> _migrations;

  /// The name of the MongoDB collection used to track applied migrations.
  /// This collection stores metadata about applied Pull Request migrations.
  static const String _migrationsCollectionName = 'pr_migrations_history';

  /// Initializes the migration service and applies any pending migrations.
  ///
  /// This method performs the following steps:
  /// 1. Ensures the `pr_migrations_history` collection exists and has a unique
  ///    index on the `prDate` field.
  /// 2. Fetches all previously applied migration PR dates from the database.
  /// 3. Sorts the registered migrations by their `prDate` string.
  /// 4. Iterates through the sorted migrations, applying only those that
  ///    have not yet been applied.
  /// 5. Records each successfully applied migration's `prDate` and `prId`
  ///    in the `pr_migrations_history` collection.
  Future<void> init() async {
    _log.info('Starting database migration process...');

    await _ensureMigrationsCollectionAndIndex();

    final appliedPrDates = await _getAppliedMigrationPrDates();
    _log.fine('Applied migration PR dates: $appliedPrDates');

    // Sort migrations by prDate to ensure chronological application.
    final sortedMigrations = [..._migrations]
      ..sort((a, b) => a.prDate.compareTo(b.prDate));

    for (final migration in sortedMigrations) {
      if (!appliedPrDates.contains(migration.prDate)) {
        _log.info(
          'Applying migration PR#${migration.prId} (Date: ${migration.prDate}): '
          '${migration.prSummary}',
        );
        try {
          await migration.up(_db, _log);
          await _recordMigration(migration.prDate, migration.prId);
          _log.info(
            'Successfully applied migration PR#${migration.prId} (Date: ${migration.prDate}).',
          );
        } catch (e, s) {
          _log.severe(
            'Failed to apply migration PR#${migration.prId} (Date: ${migration.prDate}): '
            '${migration.prSummary}',
            e,
            s,
          );
          // Re-throw to halt application startup if a migration fails.
          rethrow;
        }
      } else {
        _log.fine(
          'Migration PR#${migration.prId} (Date: ${migration.prDate}) already applied. Skipping.',
        );
      }
    }

    _log.info('Database migration process completed.');
  }

  /// Ensures the `pr_migrations_history` collection exists and has a unique index
  /// on the `prDate` field.
  Future<void> _ensureMigrationsCollectionAndIndex() async {
    _log.fine('Ensuring pr_migrations_history collection and index...');
    final collection = _db.collection(_migrationsCollectionName);
    await collection.createIndex(
      key: 'prDate',
      unique: true,
      name: 'prDate_unique_index',
    );
    _log.fine('Pr_migrations_history collection and index ensured.');
  }

  /// Retrieves a set of PR dates of all migrations that have already been
  /// applied to the database.
  Future<Set<String>> _getAppliedMigrationPrDates() async {
    final collection = _db.collection(_migrationsCollectionName);
    final documents = await collection.find().toList();
    return documents.map((doc) => doc['prDate'] as String).toSet();
  }

  /// Records a successfully applied migration in the `pr_migrations_history`
  /// collection.
  Future<void> _recordMigration(String prDate, String prId) async {
    final collection = _db.collection(_migrationsCollectionName);
    await collection.insertOne({
      'prDate': prDate,
      'prId': prId,
      'appliedAt': DateTime.now().toUtc(),
    });
  }
}
