import 'dart:async';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/storage/gcs_notification.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/idempotency_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/storage/i_storage_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/utils/media_asset_utils.dart';
import 'package:logging/logging.dart';

final _log = Logger('StorageNotificationsWebhook');

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final idempotencyService = context.read<IdempotencyService>();
    final mediaAssetRepository = context.read<DataRepository<MediaAsset>>();
    final userRepository = context.read<DataRepository<User>>();
    final headlineRepository = context.read<DataRepository<Headline>>();
    final topicRepository = context.read<DataRepository<Topic>>();
    final sourceRepository = context.read<DataRepository<Source>>();
    final storageService = context.read<IStorageService>();

    final notification = GcsNotification.fromJson(
      await context.request.json() as Map<String, dynamic>,
    );
    final messageId = notification.message.messageId;

    // 1. Idempotency Check
    if (await idempotencyService.isEventProcessed(messageId)) {
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
        await _handleObjectFinalize(
          mediaAsset: results.items.first,
          objectId: objectId,
          userRepository: userRepository,
          headlineRepository: headlineRepository,
          topicRepository: topicRepository,
          sourceRepository: sourceRepository,
          mediaAssetRepository: mediaAssetRepository,
          storageService: storageService,
        );
      case 'OBJECT_DELETE':
        await _handleObjectDelete(
          mediaAsset: results.items.first,
          userRepository: userRepository,
          headlineRepository: headlineRepository,
          topicRepository: topicRepository,
          sourceRepository: sourceRepository,
          mediaAssetRepository: mediaAssetRepository,
        );
      default:
        _log.info('Ignoring unhandled storage event type "$eventType".');
    }

    // 5. Record Idempotency
    await idempotencyService.recordEvent(messageId);

    return Response(statusCode: HttpStatus.noContent);
  } catch (e, s) {
    _log.severe('Storage notification handler failed. Returning 500.', e, s);
    // Return a non-2xx status code to signal failure to Pub/Sub,
    // which will trigger a retry according to the subscription's policy.
    return Response(statusCode: HttpStatus.internalServerError);
  }
}

Future<void> _handleObjectFinalize({
  required MediaAsset mediaAsset,
  required String objectId,
  required DataRepository<User> userRepository,
  required DataRepository<Headline> headlineRepository,
  required DataRepository<Topic> topicRepository,
  required DataRepository<Source> sourceRepository,
  required DataRepository<MediaAsset> mediaAssetRepository,
  required IStorageService storageService,
}) async {
  _log.info('Handling OBJECT_FINALIZE for asset ${mediaAsset.id}.');

  final bucketName = EnvironmentConfig.gcsBucketName;
  final publicUrl = 'https://storage.googleapis.com/$bucketName/$objectId';
  String? parentEntityId;
  MediaAssetEntityType? parentEntityType;

  // --- Link asset to parent entity (Write-Time Denormalization) ---
  switch (mediaAsset.purpose) {
    case MediaAssetPurpose.userProfilePhoto:
      final users = await userRepository.readAll(
        filter: {'mediaAssetId': mediaAsset.id},
      );
      if (users.items.isNotEmpty) {
        final userToUpdate = users.items.first;
        parentEntityId = userToUpdate.id;
        parentEntityType = MediaAssetEntityType.user;
        _log.info(
          'Found user ${userToUpdate.id} linked to asset ${mediaAsset.id}. Updating photoUrl.',
        );

        // Fire-and-forget cleanup of the old asset using its URL.
        unawaited(
          cleanupMediaAssetByUrl(
            url: userToUpdate.photoUrl,
            mediaAssetRepository: mediaAssetRepository,
            storageService: storageService,
          ).catchError(
            (Object e, StackTrace s) =>
                _log.severe('Asset cleanup failed.', e, s),
          ),
        );

        await userRepository.update(
          id: userToUpdate.id,
          item: userToUpdate.copyWith(
            photoUrl: ValueWrapper(publicUrl),
            mediaAssetId: const ValueWrapper(null),
          ),
        );
      }
    case MediaAssetPurpose.headlineImage:
      final headlines = await headlineRepository.readAll(
        filter: {'mediaAssetId': mediaAsset.id},
      );
      if (headlines.items.isNotEmpty) {
        final headlineToUpdate = headlines.items.first;
        parentEntityId = headlineToUpdate.id;
        parentEntityType = MediaAssetEntityType.headline;
        _log.info(
          'Found headline ${headlineToUpdate.id} linked to asset ${mediaAsset.id}. Updating imageUrl.',
        );

        // Fire-and-forget cleanup of old image.
        unawaited(
          cleanupMediaAssetByUrl(
            url: headlineToUpdate.imageUrl,
            mediaAssetRepository: mediaAssetRepository,
            storageService: storageService,
          ).catchError(
            (Object e, StackTrace s) =>
                _log.severe('Asset cleanup failed.', e, s),
          ),
        );

        await headlineRepository.update(
          id: headlineToUpdate.id,
          item: headlineToUpdate.copyWith(
            imageUrl: ValueWrapper(publicUrl),
            mediaAssetId: const ValueWrapper(null),
          ),
        );
      }
    case MediaAssetPurpose.topicImage:
      final topics = await topicRepository.readAll(
        filter: {'mediaAssetId': mediaAsset.id},
      );
      if (topics.items.isNotEmpty) {
        final topicToUpdate = topics.items.first;
        parentEntityId = topicToUpdate.id;
        parentEntityType = MediaAssetEntityType.topic;
        _log.info(
          'Found topic ${topicToUpdate.id} linked to asset ${mediaAsset.id}. Updating iconUrl.',
        );

        // Fire-and-forget cleanup of old image.
        unawaited(
          cleanupMediaAssetByUrl(
            url: topicToUpdate.iconUrl,
            mediaAssetRepository: mediaAssetRepository,
            storageService: storageService,
          ).catchError(
            (Object e, StackTrace s) =>
                _log.severe('Asset cleanup failed.', e, s),
          ),
        );

        await topicRepository.update(
          id: topicToUpdate.id,
          item: topicToUpdate.copyWith(
            iconUrl: ValueWrapper(publicUrl),
            mediaAssetId: const ValueWrapper(null),
          ),
        );
      }
    case MediaAssetPurpose.sourceImage:
      final sources = await sourceRepository.readAll(
        filter: {'mediaAssetId': mediaAsset.id},
      );
      if (sources.items.isNotEmpty) {
        final sourceToUpdate = sources.items.first;
        parentEntityId = sourceToUpdate.id;
        parentEntityType = MediaAssetEntityType.source;
        _log.info(
          'Found source ${sourceToUpdate.id} linked to asset ${mediaAsset.id}. Updating logoUrl.',
        );

        // Fire-and-forget cleanup of old image.
        unawaited(
          cleanupMediaAssetByUrl(
            url: sourceToUpdate.logoUrl,
            mediaAssetRepository: mediaAssetRepository,
            storageService: storageService,
          ).catchError(
            (Object e, StackTrace s) =>
                _log.severe('Asset cleanup failed.', e, s),
          ),
        );

        await sourceRepository.update(
          id: sourceToUpdate.id,
          item: sourceToUpdate.copyWith(
            logoUrl: ValueWrapper(publicUrl),
            mediaAssetId: const ValueWrapper(null),
          ),
        );
      }
  }

  // Finalize MediaAsset status
  final updatedAsset = mediaAsset.copyWith(
    status: MediaAssetStatus.completed,
    publicUrl: publicUrl,
    associatedEntityId: parentEntityId,
    associatedEntityType: parentEntityType,
    updatedAt: DateTime.now(),
  );

  await mediaAssetRepository.update(id: mediaAsset.id, item: updatedAsset);
  _log.info('Finalized media asset ${mediaAsset.id} to "completed".');
}

Future<void> _handleObjectDelete({
  required MediaAsset mediaAsset,
  required DataRepository<User> userRepository,
  required DataRepository<Headline> headlineRepository,
  required DataRepository<Topic> topicRepository,
  required DataRepository<Source> sourceRepository,
  required DataRepository<MediaAsset> mediaAssetRepository,
}) async {
  _log.info('Handling OBJECT_DELETE for asset ${mediaAsset.id}.');

  // If the asset was associated with an entity, nullify the URL on that entity.
  final entityId = mediaAsset.associatedEntityId;
  final entityType = mediaAsset.associatedEntityType;

  if (entityId != null && entityType != null) {
    _log.info(
      'Asset ${mediaAsset.id} was associated with $entityType $entityId. Nullifying URL.',
    );
    try {
      switch (entityType) {
        case MediaAssetEntityType.user:
          final user = await userRepository.read(id: entityId);
          if (user.photoUrl == mediaAsset.publicUrl) {
            await userRepository.update(
              id: user.id,
              item: user.copyWith(photoUrl: const ValueWrapper(null)),
            );
          }
        case MediaAssetEntityType.headline:
          final headline = await headlineRepository.read(id: entityId);
          if (headline.imageUrl == mediaAsset.publicUrl) {
            await headlineRepository.update(
              id: headline.id,
              item: headline.copyWith(imageUrl: const ValueWrapper(null)),
            );
          }
        case MediaAssetEntityType.topic:
          final topic = await topicRepository.read(id: entityId);
          if (topic.iconUrl == mediaAsset.publicUrl) {
            await topicRepository.update(
              id: topic.id,
              item: topic.copyWith(iconUrl: const ValueWrapper(null)),
            );
          }
        case MediaAssetEntityType.source:
          final source = await sourceRepository.read(id: entityId);
          if (source.logoUrl == mediaAsset.publicUrl) {
            await sourceRepository.update(
              id: source.id,
              item: source.copyWith(logoUrl: const ValueWrapper(null)),
            );
          }
      }
    } catch (e, s) {
      _log.severe('Failed to nullify URL on parent entity $entityId.', e, s);
      // Continue to delete the asset record regardless.
    }
  }

  // Delete the corresponding MediaAsset record from the database.
  await mediaAssetRepository.delete(id: mediaAsset.id);
  _log.info('Deleted MediaAsset record ${mediaAsset.id} from database.');
}
