import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/media_asset_purpose.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/media_asset_status.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/media_asset.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/idempotency_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('GcsNotificationsWebhook');

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final idempotencyService = context.read<IdempotencyService>();
  final mediaAssetRepository = context.read<DataRepository<MediaAsset>>();
  final userRepository = context.read<DataRepository<User>>();

  final body = await context.request.json() as Map<String, dynamic>;

  // GCS Pub/Sub notifications are wrapped in a 'message' object.
  final message = body['message'] as Map<String, dynamic>?;
  if (message == null) {
    _log.warning('Invalid GCS notification format: missing "message" object.');
    throw const BadRequestException('Invalid GCS notification format.');
  }

  final messageId = message['messageId'] as String?;
  final attributes = message['attributes'] as Map<String, dynamic>?;

  if (messageId == null || attributes == null) {
    _log.warning('Invalid GCS notification: missing messageId or attributes.');
    throw const BadRequestException('Invalid GCS notification format.');
  }

  // 1. Idempotency Check
  if (await idempotencyService.isEventProcessed(messageId)) {
    _log.info('GCS event $messageId already processed. Acknowledging.');
    return Response(statusCode: HttpStatus.ok);
  }

  // 2. Process Event
  final eventType = attributes['eventType'] as String?;
  final objectId = attributes['objectId'] as String?; // This is the storagePath

  if (eventType != 'OBJECT_FINALIZE' || objectId == null) {
    _log.info('Ignoring GCS event of type "$eventType". Acknowledging.');
    return Response(statusCode: HttpStatus.ok);
  }

  _log.info('Processing OBJECT_FINALIZE event for path: "$objectId"');

  // 3. Find MediaAsset
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

  final mediaAsset = results.items.first;

  // 4. Perform Business Logic (e.g., update user profile)
  if (mediaAsset.purpose == MediaAssetPurpose.userProfilePhoto) {
    try {
      final user = await userRepository.read(id: mediaAsset.userId);
      final bucketName = EnvironmentConfig.gcsBucketName;
      final publicUrl = 'https://storage.googleapis.com/$bucketName/$objectId';

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

  // 5. Finalize MediaAsset status
  final bucketName = EnvironmentConfig.gcsBucketName;
  final publicUrl = 'https://storage.googleapis.com/$bucketName/$objectId';
  final updatedAsset = mediaAsset.copyWith(
    status: MediaAssetStatus.completed,
    publicUrl: publicUrl,
    updatedAt: DateTime.now(),
  );

  await mediaAssetRepository.update(id: mediaAsset.id, item: updatedAsset);
  _log.info('Finalized media asset ${mediaAsset.id} to "completed".');

  // 6. Record Idempotency
  await idempotencyService.recordEvent(messageId);

  return Response(statusCode: HttpStatus.noContent);
}
