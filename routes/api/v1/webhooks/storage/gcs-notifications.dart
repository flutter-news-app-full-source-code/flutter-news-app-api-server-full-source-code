import 'dart:async';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/media/gcs_notification.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/idempotency_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/storage/i_storage_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('GcsNotificationsWebhook');

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final idempotencyService = context.read<IdempotencyService>();
  final mediaAssetRepository = context.read<DataRepository<MediaAsset>>();
  final userRepository = context.read<DataRepository<User>>();
  final storageService = context.read<IStorageService>();

  final notification = GcsNotification.fromJson(
    await context.request.json() as Map<String, dynamic>,
  );
  final messageId = notification.message.messageId;

  // 1. Idempotency Check
  if (await idempotencyService.isEventProcessed(messageId)) {
    _log.info('GCS event $messageId already processed. Acknowledging.');
    return Response(statusCode: HttpStatus.ok);
  }

  // 2. Process Event
  final eventType = notification.message.attributes.eventType;
  final objectId = notification.message.attributes.objectId;

  _log.info('Processing GCS event "$eventType" for path: "$objectId"');

  // 3. Find MediaAsset by its storage path.
  final results = await mediaAssetRepository.readAll(
    filter: {'storagePath': objectId},
    pagination: const PaginationOptions(limit: 1),
  );

  if (results.items.isEmpty) {
    _log.severe(
      'Received GCS notification for unknown storagePath: "$objectId"',
    );
    // Acknowledge to prevent retries for an unrecoverable error.
    return Response(statusCode: HttpStatus.ok);
  }

  // 4. Handle different event types.
  switch (eventType) {
    case 'OBJECT_FINALIZE':
      await _handleObjectFinalize(
        mediaAsset: results.items.first,
        objectId: objectId,
        userRepository: userRepository,
        mediaAssetRepository: mediaAssetRepository,
        storageService: storageService,
      );
    case 'OBJECT_DELETE':
      await _handleObjectDelete(
        mediaAsset: results.items.first,
        userRepository: userRepository,
        mediaAssetRepository: mediaAssetRepository,
      );
    default:
      _log.info('Ignoring unhandled GCS event type "$eventType".');
  }

  // 5. Record Idempotency
  await idempotencyService.recordEvent(messageId);

  return Response(statusCode: HttpStatus.noContent);
}

Future<void> _handleObjectFinalize({
  required MediaAsset mediaAsset,
  required String objectId,
  required DataRepository<User> userRepository,
  required DataRepository<MediaAsset> mediaAssetRepository,
  required IStorageService storageService,
}) async {
  _log.info('Handling OBJECT_FINALIZE for asset ${mediaAsset.id}.');

  final bucketName = EnvironmentConfig.gcsBucketName;
  final publicUrl = 'https://storage.googleapis.com/$bucketName/$objectId';

  // Perform Business Logic (e.g., update user profile)
  if (mediaAsset.purpose == MediaAssetPurpose.userProfilePhoto) {
    try {
      final user = await userRepository.read(id: mediaAsset.userId);

      // Fire-and-forget the cleanup of the old asset.
      unawaited(
        _cleanupOldProfilePhoto(
          user: user,
          newAsset: mediaAsset,
          mediaAssetRepository: mediaAssetRepository,
          storageService: storageService,
        ),
      );

      await userRepository.update(
        id: user.id,
        item: user.copyWith(photoUrl: publicUrl),
      );
      _log.info('Updated profile photo for user ${user.id}.');
    } catch (e, s) {
      _log.severe(
        'Failed to update user profile photo for media asset ${mediaAsset.id}',
        e,
        s,
      );
    }
  }

  // Finalize MediaAsset status
  final updatedAsset = mediaAsset.copyWith(
    status: MediaAssetStatus.completed,
    publicUrl: publicUrl,
    updatedAt: DateTime.now(),
  );

  await mediaAssetRepository.update(id: mediaAsset.id, item: updatedAsset);
  _log.info('Finalized media asset ${mediaAsset.id} to "completed".');
}

Future<void> _handleObjectDelete({
  required MediaAsset mediaAsset,
  required DataRepository<User> userRepository,
  required DataRepository<MediaAsset> mediaAssetRepository,
}) async {
  _log.info('Handling OBJECT_DELETE for asset ${mediaAsset.id}.');

  // If the deleted asset was a user's profile photo, nullify the user's photoUrl.
  if (mediaAsset.purpose == MediaAssetPurpose.userProfilePhoto) {
    final user = await userRepository.read(id: mediaAsset.userId);
    // Only update if the user's current photoUrl matches the deleted asset.
    if (user.photoUrl == mediaAsset.publicUrl) {
      await userRepository.update(
        id: user.id,
        item: user.copyWith(photoUrl: null),
      );
      _log.info('Nulled profile photo for user ${user.id}.');
    }
  }

  // Delete the corresponding MediaAsset record from the database.
  await mediaAssetRepository.delete(id: mediaAsset.id);
  _log.info('Deleted MediaAsset record ${mediaAsset.id} from database.');
}

Future<void> _cleanupOldProfilePhoto({
  required User user,
  required MediaAsset newAsset,
  required DataRepository<MediaAsset> mediaAssetRepository,
  required IStorageService storageService,
}) async {
  final oldAssets = await mediaAssetRepository.readAll(
    filter: {
      'userId': user.id,
      'purpose': MediaAssetPurpose.userProfilePhoto.name,
      '_id': {r'$ne': newAsset.id}, // Exclude the newly uploaded asset
    },
  );

  if (oldAssets.items.isEmpty) return;

  _log.info('Found ${oldAssets.items.length} old profile photos to clean up.');
  for (final oldAsset in oldAssets.items) {
    try {
      await storageService.deleteObject(storagePath: oldAsset.storagePath);
      await mediaAssetRepository.delete(id: oldAsset.id);
      _log.info('Cleaned up old asset: ${oldAsset.id}');
    } catch (e, s) {
      _log.severe('Failed to clean up old asset ${oldAsset.id}', e, s);
    }
  }
}
