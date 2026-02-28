import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/storage/s3_notification.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/storage/sns_notification.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/idempotency_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/media_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/utils/sns_message_handler.dart';
import 'package:logging/logging.dart';

final _log = Logger('S3NotificationsWebhook');

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final idempotencyService = context.read<IdempotencyService>();
    final mediaService = context.read<MediaService>();
    final mediaAssetRepository = context.read<DataRepository<MediaAsset>>();
    final snsMessageHandler = context.read<SnsMessageHandler>();

    final bodyString = await context.request.body();
    final jsonBody = jsonDecode(bodyString) as Map<String, dynamic>;

    // Attempt to parse as an SNS Notification first (wrapping S3 event).
    SnsNotification? snsPayload;
    try {
      // Check if it looks like an SNS payload before parsing to avoid noise.
      if (jsonBody.containsKey('Type') && jsonBody.containsKey('MessageId')) {
        snsPayload = SnsNotification.fromJson(jsonBody);
      }
    } catch (e) {
      _log.fine('Payload is not a valid SNS notification: $e');
    }

    // 1. Handle AWS SNS Subscription Confirmation
    if (snsPayload != null && snsPayload.type == 'SubscriptionConfirmation') {
      final subscribeUrl = snsPayload.subscribeUrl;
      if (subscribeUrl != null) {
        await snsMessageHandler.confirmSubscription(subscribeUrl);
      } else {
        _log.warning(
          'Received SubscriptionConfirmation but SubscribeURL is null.',
        );
      }
      return Response(statusCode: HttpStatus.ok);
    }

    // 2. Extract S3 Notification Data
    late final S3Notification s3Notification;
    try {
      if (snsPayload != null && snsPayload.type == 'Notification') {
        // Unwrap SNS Message
        final messageJson =
            jsonDecode(snsPayload.message ?? '{}') as Map<String, dynamic>;
        s3Notification = S3Notification.fromJson(messageJson);
      } else {
        // Assume direct S3 invocation
        s3Notification = S3Notification.fromJson(jsonBody);
      }
    } catch (e) {
      _log.warning('Failed to parse S3 notification structure.', e);
      // If we can't parse it as S3, ignore it.
      return Response(statusCode: HttpStatus.ok);
    }

    if (s3Notification.records.isEmpty) {
      _log.info('No Records found in S3 notification. Ignoring.');
      return Response(statusCode: HttpStatus.ok);
    }

    for (final record in s3Notification.records) {
      final eventName = record.eventName;
      final objectKey = record.s3.object.decodedKey;

      // Use a composite ID for idempotency: EventName + ObjectKey
      // S3 doesn't provide a single unique message ID for the whole batch in the same way GCS does.
      final eventId = '${eventName}_$objectKey';

      if (await idempotencyService.isEventProcessed(eventId, scope: 's3')) {
        _log.info('S3 event $eventId already processed. Skipping.');
        continue;
      }

      _log.info('Processing S3 event "$eventName" for key: "$objectKey"');

      // 3. Find MediaAsset
      final results = await mediaAssetRepository.readAll(
        filter: {'storagePath': objectKey},
        pagination: const PaginationOptions(limit: 1),
      );

      if (results.items.isEmpty) {
        _log.warning(
          'Received S3 notification for unknown storagePath: "$objectKey"',
        );
        continue;
      }

      final asset = results.items.first;

      // 4. Handle Events
      if (eventName.startsWith('ObjectCreated:')) {
        final bucketName = EnvironmentConfig.awsBucketName;
        final region = EnvironmentConfig.awsRegion;

        // Construct public URL. If custom endpoint (MinIO), use that. Else standard AWS.
        final publicUrl =
            'https://$bucketName.s3.$region.amazonaws.com/$objectKey';

        await mediaService.finalizeUpload(
          mediaAsset: asset,
          publicUrl: publicUrl,
        );
      } else if (eventName.startsWith('ObjectRemoved:')) {
        await mediaService.handleAssetDeletion(asset);
      }

      await idempotencyService.recordEvent(eventId, scope: 's3');
    }

    return Response(statusCode: HttpStatus.noContent);
  } catch (e, s) {
    _log.severe('S3 notification handler failed.', e, s);
    return Response(statusCode: HttpStatus.internalServerError);
  }
}
