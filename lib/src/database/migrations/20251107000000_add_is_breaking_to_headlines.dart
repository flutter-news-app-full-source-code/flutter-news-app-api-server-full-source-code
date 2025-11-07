import 'package:flutter_news_app_api_server_full_source_code/src/database/migration.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Migration to add the `isBreaking` field to existing `Headline` documents.
///
/// This migration ensures that all existing documents in the `headlines`
/// collection have the `isBreaking` boolean field, defaulting to `false`
/// if it does not already exist. This is crucial for schema consistency
/// when introducing the breaking news feature.
class AddIsBreakingToHeadlines extends Migration {
  /// {@macro add_is_breaking_to_headlines}
  AddIsBreakingToHeadlines()
    : super(
        prDate: '20251107000000',
        prId: '71',
        prSummary:
            'Adds the isBreaking field to existing Headline documents, '
            'defaulting to false.',
      );

  @override
  Future<void> up(Db db, Logger log) async {
    final collection = db.collection('headlines');

    log.info(
      'Attempting to add "isBreaking: false" to Headline documents '
      'where the field is missing...',
    );

    // Update all documents in the 'headlines' collection that do not
    // already have the 'isBreaking' field, setting it to false.
    final updateResult = await collection.updateMany(
      where
          .exists('isBreaking')
          .not(), // Select documents where isBreaking does not exist
      modify.set('isBreaking', false), // Set isBreaking to false
    );

    log.info(
      'Added "isBreaking: false" to ${updateResult.nModified} Headline documents.',
    );
  }

  @override
  Future<void> down(Db db, Logger log) async {
    log.warning(
      'Reverting "AddIsBreakingToHeadlines" is not supported. '
      'The "isBreaking" field would need to be manually removed if required.',
    );
  }
}
