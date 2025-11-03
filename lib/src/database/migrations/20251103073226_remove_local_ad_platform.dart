import 'package:flutter_news_app_api_server_full_source_code/src/database/migration.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Migration to remove the legacy `local` ad platform from the `remote_configs`
/// collection.
///
/// This migration performs two critical cleanup tasks:
/// 1. It removes the `local` key from the `adConfig.platformAdIdentifiers` map
///    in all `remote_configs` documents.
/// 2. It updates any `remote_configs` document where the `primaryAdPlatform`
///    is set to `local`, changing it to `admob`.
///
/// This ensures data consistency after the removal of the `AdPlatformType.local`
/// enum value and prevents deserialization errors in the application.
class RemoveLocalAdPlatform extends Migration {
  /// {@macro remove_local_ad_platform}
  RemoveLocalAdPlatform()
    : super(
        prDate: '20251103073226',
        prId: '57',
        prSummary:
            'Removes the legacy local ad platform from the remote config, migrating existing data to use admob as the default.',
      );

  @override
  Future<void> up(Db db, Logger log) async {
    final collection = db.collection('remote_configs');

    // Step 1: Unset the 'local' key from the platformAdIdentifiers map.
    // This removes the field entirely from any document where it exists.
    log.info(
      'Attempting to remove "adConfig.platformAdIdentifiers.local" field...',
    );
    final unsetResult = await collection.updateMany(
      where.exists('adConfig.platformAdIdentifiers.local'),
      modify.unset('adConfig.platformAdIdentifiers.local'),
    );
    log.info(
      'Removed "adConfig.platformAdIdentifiers.local" from ${unsetResult.nModified} documents.',
    );

    // Step 2: Update the primaryAdPlatform from 'local' to 'admob'.
    // This ensures that no document is left with an invalid primary platform.
    log.info(
      'Attempting to migrate primaryAdPlatform from "local" to "admob"...',
    );
    final updateResult = await collection.updateMany(
      where.eq('adConfig.primaryAdPlatform', 'local'),
      modify.set('adConfig.primaryAdPlatform', 'admob'),
    );
    log.info(
      'Migrated primaryAdPlatform to "admob" for ${updateResult.nModified} documents.',
    );
  }

  @override
  Future<void> down(Db db, Logger log) async {
    // Reverting this change is not safe as it would require re-introducing
    // an enum value that no longer exists in the code.
    log.warning(
      'Reverting "RemoveLocalAdPlatform" is not supported. The "local" ad platform configuration would need to be manually restored if required.',
    );
  }
}
