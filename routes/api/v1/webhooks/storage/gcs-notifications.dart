import 'dart:async';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/storage/gcs_notification.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/idempotency_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/media_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('StorageNotificationsWebhook');

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final idempotencyService = context.read<IdempotencyService>();
    final mediaService = context.read<MediaService>();
    final mediaAssetRepository = context.read<DataRepository<MediaAsset>>();

    final notification = GcsNotification.fromJson(
      await context.request.json() as Map<String, dynamic>,
    );
    final messageId = notification.message.messageId;

    // 1. Idempotency Check
    if (await idempotencyService.isEventProcessed(
      messageId,
      scope: 'gcs',
    )) {
      _log.info('Storage event $messageId already processed. Acknowledging.');
      return Response(statusCode: HttpStatus.ok);
    }

    // 2. Process Event
    final eventType = notification.message.attributes.eventType;
    final objectId = notification.message.attributes.objectId;

    _log.info('Processing storage event "$eventType" for path: "$objectId"');

    // 3. Find MediaAsset by its storage path.
    final results = await mediaAssetRepository.readAll(
      filter: {'storagePath': objectId},
      pagination: const PaginationOptions(limit: 1),
    );

    if (results.items.isEmpty) {
      _log.severe(
        'Received storage notification for unknown storagePath: "$objectId"',
      );
      // Acknowledge to prevent retries for an unrecoverable error.
      return Response(statusCode: HttpStatus.ok);
    }

    // 4. Handle different event types.
    switch (eventType) {
      case 'OBJECT_FINALIZE':
        final bucketName = EnvironmentConfig.gcsBucketName;
        final publicUrl =
            'https://storage.googleapis.com/$bucketName/$objectId';
        await mediaService.finalizeUpload(
          mediaAsset: results.items.first,
          publicUrl: publicUrl,
        );
      case 'OBJECT_DELETE':
        await mediaService.handleAssetDeletion(results.items.first);
      default:
        _log.info('Ignoring unhandled storage event type "$eventType".');
    }

    // 5. Record Idempotency
    await idempotencyService.recordEvent(messageId, scope: 'gcs');

    return Response(statusCode: HttpStatus.noContent);
  } catch (e, s) {
    _log.severe('Storage notification handler failed. Returning 500.', e, s);
    // Return a non-2xx status code to signal failure to Pub/Sub,
    // which will trigger a retry according to the subscription's policy.
    return Response(statusCode: HttpStatus.internalServerError);
  }
}
