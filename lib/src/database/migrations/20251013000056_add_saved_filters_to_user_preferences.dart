import 'package:flutter_news_app_api_server_full_source_code/src/database/migration.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Migration to add the `savedFilters` field to existing
/// `user_content_preferences` documents.
class AddSavedFiltersToUserPreferences extends Migration {
  /// {@macro add_saved_filters_to_user_preferences}
  AddSavedFiltersToUserPreferences()
    : super(
        prDate: '20251013000056',
        prId: '56',
        prSummary: 'Add savedFilters field to user_content_preferences',
      );

  @override
  Future<void> up(Db db, Logger log) async {
    final collection = db.collection('user_content_preferences');
    final result = await collection.updateMany(
      // Filter for documents where 'savedFilters' does not exist.
      where.notExists('savedFilters'),
      // Set 'savedFilters' to an empty array.
      modify.set('savedFilters', <dynamic>[]),
    );
    log.info(
      'Updated ${result.nModified} documents in user_content_preferences.',
    );
  }

  @override
  Future<void> down(Db db, Logger log) async {
    final collection = db.collection('user_content_preferences');
    await collection.updateMany(
      where.exists('savedFilters'),
      modify.unset('savedFilters'),
    );
    log.info('Removed "savedFilters" field from user_content_preferences.');
  }
}
