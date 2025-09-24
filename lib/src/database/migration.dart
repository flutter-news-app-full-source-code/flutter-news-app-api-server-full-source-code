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
    required this.version,
    required this.description,
    this.gitHubPullRequest,
  });

  /// A unique identifier for the migration, following the `YYYYMMDDHHMMSS`
  /// format (e.g., '20250924083500'). This ensures chronological ordering.
  final String version;

  /// A human-readable description of the migration's purpose.
  final String description;

  /// An optional URL or identifier for the GitHub Pull Request that introduced
  /// the schema changes addressed by this migration.
  ///
  /// This provides valuable context for future maintainers, linking the
  /// database migration directly to the code changes that necessitated it.
  final String? gitHubPullRequest;

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
