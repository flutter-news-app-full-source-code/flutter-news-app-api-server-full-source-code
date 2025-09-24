// ignore_for_file: comment_references

import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template migration}
/// An abstract base class for defining database migration scripts.
///
/// Each concrete migration must extend this class and implement the [up] and
/// [down] methods. Migrations are identified by a unique [version] string
/// (following the `YYYYMMDDHHMMSS` format) and a [description].
///
/// Implementations of [up] and [down] must be **idempotent**, meaning they
/// can be safely run multiple times without causing errors or incorrect data.
/// This is crucial for robust database schema evolution.
/// {@endtemplate}
abstract class Migration {
  /// {@macro migration}
  const Migration({
    required this.prDate,
    required this.prSummary,
    required this.prId,
  });

  /// The merge date and time of the Pull Request that introduced this
  /// migration, in `YYYYMMDDHHMMSS` format (e.g., '20250924083500').
  ///
  /// This serves as the unique, chronological identifier for the migration,
  /// ensuring that migrations are applied in the correct order.
  final String prDate;

  /// A concise summary of the changes introduced by the Pull Request that
  /// this migration addresses.
  ///
  /// This provides a human-readable description of the migration's purpose.
  final String prSummary;

  /// The unique identifier of the GitHub Pull Request that introduced the
  /// schema changes addressed by this migration (e.g., '50').
  ///
  /// This provides direct traceability, linking the database migration to the
  /// specific code changes on GitHub.
  final String prId;

  /// Applies the migration, performing necessary schema changes or data
  /// transformations.
  ///
  /// This method is executed when the migration is run. It receives the
  /// MongoDB [db] instance and a [Logger] for logging progress and errors.
  ///
  /// Implementations **must** be idempotent.
  Future<void> up(Db db, Logger log);

  /// Reverts the migration, undoing the changes made by the [up] method.
  ///
  /// This method is executed when a migration needs to be rolled back. It
  /// receives the MongoDB [db] instance and a [Logger].
  ///
  /// Implementations **must** be idempotent. While optional for simple
  /// forward-only migrations, providing a `down` method is a best practice
  /// for professional systems to enable rollback capabilities.
  Future<void> down(Db db, Logger log);
}
