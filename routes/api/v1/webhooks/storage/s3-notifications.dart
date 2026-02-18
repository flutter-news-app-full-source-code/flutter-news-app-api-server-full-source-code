import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/idempotency_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/media_service.dart';
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

    final bodyString = await context.request.body();
    final jsonBody = jsonDecode(bodyString) as Map<String, dynamic>;

    // 1. Handle AWS SNS Subscription Confirmation (if applicable)
    if (jsonBody['Type'] == 'SubscriptionConfirmation') {
      _log.info(
        'Received SNS SubscriptionConfirmation. Log URL to confirm manually or implement auto-confirm.',
      );
      _log.info('SubscribeURL: ${jsonBody['SubscribeURL']}');
      return Response(statusCode: HttpStatus.ok);
    }

    // 2. Unwrap SNS Message if present
    var recordsJson = jsonBody;
    if (jsonBody['Type'] == 'Notification' && jsonBody.containsKey('Message')) {
      try {
        recordsJson =
            jsonDecode(jsonBody['Message'] as String) as Map<String, dynamic>;
      } catch (e) {
        _log.warning(
          'Failed to parse SNS Message body as JSON. It might be raw text.',
        );
      }
    }

    if (!recordsJson.containsKey('Records')) {
      _log.info('No Records found in S3 notification. Ignoring.');
      return Response(statusCode: HttpStatus.ok);
    }

    final records = recordsJson['Records'] as List<dynamic>;

    for (final record in records) {
      final recordMap = record as Map<String, dynamic>;
      final eventName = recordMap['eventName'] as String?;
      final s3 = recordMap['s3'] as Map<String, dynamic>?;

      if (eventName == null || s3 == null) continue;

      final objectKey = Uri.decodeFull(
        (s3['object'] as Map<String, dynamic>)['key'] as String,
      );

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
        final endpoint = EnvironmentConfig.awsS3Endpoint;

        // Construct public URL. If custom endpoint (MinIO), use that. Else standard AWS.
        final publicUrl = endpoint != null
            ? '$endpoint/$bucketName/$objectKey'
            : 'https://$bucketName.s3.$region.amazonaws.com/$objectKey';

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
