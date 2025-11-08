import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/database/migration.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template add_push_notification_config_to_remote_config}
/// A database migration to add the `pushNotificationConfig` field to the
/// `remote_configs` document.
///
/// This migration ensures that the `remote_configs` document contains the
/// necessary structure for push notification settings, preventing errors when
/// the application starts and tries to access this configuration. It is
/// designed to be idempotent and safe to run multiple times.
/// {@endtemplate}
class AddPushNotificationConfigToRemoteConfig extends Migration {
  /// {@macro add_push_notification_config_to_remote_config}
  AddPushNotificationConfigToRemoteConfig()
    : super(
        prId: '71',
        prSummary:
            'Add pushNotificationConfig field to the remote_configs document.',
        prDate: '20251108103300',
      );

  @override
  Future<void> up(Db db, Logger log) async {
    log.info('Running up migration: $prSummary');

    final remoteConfigCollection = db.collection('remote_configs');
    final remoteConfigId = ObjectId.fromHexString(kRemoteConfigId);

    // Default structure for the push notification configuration.
    final pushNotificationConfig =
        remoteConfigsFixturesData.first.pushNotificationConfig;

    // Use $set to add the field only if it doesn't exist.
    // This is an idempotent operation.
    await remoteConfigCollection.updateOne(
      where
          .id(remoteConfigId)
          .and(
            where.notExists('pushNotificationConfig'),
          ),
      modify.set('pushNotificationConfig', pushNotificationConfig.toJson()),
    );

    log.info('Successfully completed up migration for $prDate.');
  }

  @override
  Future<void> down(Db db, Logger log) async {
    log.info('Running down migration: $prSummary');
    // This migration is additive. The `down` method will unset the field.
    final remoteConfigCollection = db.collection('remote_configs');
    final remoteConfigId = ObjectId.fromHexString(kRemoteConfigId);
    await remoteConfigCollection.updateOne(
      where.id(remoteConfigId),
      modify.unset('pushNotificationConfig'),
    );
    log.info('Successfully completed down migration for $prDate.');
  }
}
