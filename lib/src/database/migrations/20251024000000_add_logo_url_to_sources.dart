import 'package:flutter_news_app_api_server_full_source_code/src/database/migration.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Migration to add the `logoUrl` field to existing `sources` documents.
class AddLogoUrlToSources extends Migration {
  /// {@macro add_logo_url_to_sources}
  AddLogoUrlToSources()
    : super(
        prDate: '20251024000000',
        prId: '60',
        prSummary:
            'Adds the required `logoUrl` field to all existing '
            'documents in the `sources` collection to align with the '
            'core v1.3.0 model update.',
      );

  @override
  Future<void> up(Db db, Logger log) async {
    final collection = db.collection('sources');
    final sourcesToUpdate = await collection
        .find(where.notExists('logoUrl'))
        .toList();

    if (sourcesToUpdate.isEmpty) {
      log.info('No sources found needing a logoUrl. Migration is up to date.');
      return;
    }

    log.info(
      'Found ${sourcesToUpdate.length} sources to update with a logoUrl.',
    );
    var count = 0;
    for (final source in sourcesToUpdate) {
      final sourceUrl = source['url'] as String?;
      if (sourceUrl != null && sourceUrl.isNotEmpty) {
        try {
          final host = Uri.parse(sourceUrl).host;
          final logoUrl = 'https://logo.clearbit.com/$host?size=200';
          await collection.updateOne(
            where.id(source['_id'] as ObjectId),
            modify.set('logoUrl', logoUrl),
          );
          count++;
        } catch (e) {
          log.warning(
            'Could not parse URL for source ${source['_id']}: $sourceUrl',
          );
        }
      }
    }
    log.info('Updated $count sources with a new logoUrl.');
  }

  @override
  Future<void> down(Db db, Logger log) async {
    final collection = db.collection('sources');
    await collection.updateMany(
      where.exists('logoUrl'),
      modify.unset('logoUrl'),
    );
    log.info(
      'Removed "logoUrl" field from all documents in the sources collection.',
    );
  }
}
