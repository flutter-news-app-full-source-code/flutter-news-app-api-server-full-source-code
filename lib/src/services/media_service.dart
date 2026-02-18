import 'dart:async';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/storage/i_storage_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/util/media_asset_utils.dart';
import 'package:logging/logging.dart';

/// {@template media_service}
/// A service responsible for managing the lifecycle of media assets.
///
/// This includes finalizing assets after upload (linking them to their parent
/// entities) and handling asset deletion/cleanup. It abstracts the business
/// logic away from specific webhook handlers (GCS, S3).
/// {@endtemplate}
class MediaService {
  /// {@macro media_service}
  const MediaService({
    required DataRepository<MediaAsset> mediaAssetRepository,
    required DataRepository<User> userRepository,
    required DataRepository<Headline> headlineRepository,
    required DataRepository<Topic> topicRepository,
    required DataRepository<Source> sourceRepository,
    required IStorageService storageService,
    required Logger log,
  }) : _mediaAssetRepository = mediaAssetRepository,
       _userRepository = userRepository,
       _headlineRepository = headlineRepository,
       _topicRepository = topicRepository,
       _sourceRepository = sourceRepository,
       _storageService = storageService,
       _log = log;

  final DataRepository<MediaAsset> _mediaAssetRepository;
  final DataRepository<User> _userRepository;
  final DataRepository<Headline> _headlineRepository;
  final DataRepository<Topic> _topicRepository;
  final DataRepository<Source> _sourceRepository;
  final IStorageService _storageService;
  final Logger _log;

  /// Finalizes a media asset after a successful upload.
  ///
  /// This method:
  /// 1. Identifies the parent entity (User, Headline, etc.) waiting for this asset.
  /// 2. Updates the parent entity with the new [publicUrl].
  /// 3. Cleans up any old media assets associated with the parent entity.
  /// 4. Updates the [MediaAsset] status to [MediaAssetStatus.completed].
  Future<void> finalizeUpload({
    required MediaAsset mediaAsset,
    required String publicUrl,
  }) async {
    _log.info('Finalizing upload for asset ${mediaAsset.id}.');

    String? parentEntityId;
    MediaAssetEntityType? parentEntityType;

    // --- Link asset to parent entity (Write-Time Denormalization) ---
    switch (mediaAsset.purpose) {
      case MediaAssetPurpose.userProfilePhoto:
        final users = await _userRepository.readAll(
          filter: {'mediaAssetId': mediaAsset.id},
        );
        if (users.items.isNotEmpty) {
          final userToUpdate = users.items.first;
          parentEntityId = userToUpdate.id;
          parentEntityType = MediaAssetEntityType.user;
          _log.info(
            'Found user ${userToUpdate.id} linked to asset ${mediaAsset.id}. Updating photoUrl.',
          );

          await _cleanupOldAsset(userToUpdate.photoUrl);

          await _userRepository.update(
            id: userToUpdate.id,
            item: userToUpdate.copyWith(
              photoUrl: ValueWrapper(publicUrl),
              mediaAssetId: const ValueWrapper(null),
            ),
          );
        }
      case MediaAssetPurpose.headlineImage:
        final headlines = await _headlineRepository.readAll(
          filter: {'mediaAssetId': mediaAsset.id},
        );
        if (headlines.items.isNotEmpty) {
          final headlineToUpdate = headlines.items.first;
          parentEntityId = headlineToUpdate.id;
          parentEntityType = MediaAssetEntityType.headline;
          _log.info(
            'Found headline ${headlineToUpdate.id} linked to asset ${mediaAsset.id}. Updating imageUrl.',
          );

          await _cleanupOldAsset(headlineToUpdate.imageUrl);

          await _headlineRepository.update(
            id: headlineToUpdate.id,
            item: headlineToUpdate.copyWith(
              imageUrl: ValueWrapper(publicUrl),
              mediaAssetId: const ValueWrapper(null),
            ),
          );
        }
      case MediaAssetPurpose.topicImage:
        final topics = await _topicRepository.readAll(
          filter: {'mediaAssetId': mediaAsset.id},
        );
        if (topics.items.isNotEmpty) {
          final topicToUpdate = topics.items.first;
          parentEntityId = topicToUpdate.id;
          parentEntityType = MediaAssetEntityType.topic;
          _log.info(
            'Found topic ${topicToUpdate.id} linked to asset ${mediaAsset.id}. Updating iconUrl.',
          );

          await _cleanupOldAsset(topicToUpdate.iconUrl);

          await _topicRepository.update(
            id: topicToUpdate.id,
            item: topicToUpdate.copyWith(
              iconUrl: ValueWrapper(publicUrl),
              mediaAssetId: const ValueWrapper(null),
            ),
          );
        }
      case MediaAssetPurpose.sourceImage:
        final sources = await _sourceRepository.readAll(
          filter: {'mediaAssetId': mediaAsset.id},
        );
        if (sources.items.isNotEmpty) {
          final sourceToUpdate = sources.items.first;
          parentEntityId = sourceToUpdate.id;
          parentEntityType = MediaAssetEntityType.source;
          _log.info(
            'Found source ${sourceToUpdate.id} linked to asset ${mediaAsset.id}. Updating logoUrl.',
          );

          await _cleanupOldAsset(sourceToUpdate.logoUrl);

          await _sourceRepository.update(
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

    await _mediaAssetRepository.update(id: mediaAsset.id, item: updatedAsset);
    _log.info('Finalized media asset ${mediaAsset.id} to "completed".');
  }

  /// Handles the deletion of a media asset file.
  ///
  /// If the asset was associated with an entity, this method nullifies the
  /// corresponding URL field on that entity to prevent broken links.
  Future<void> handleAssetDeletion(MediaAsset mediaAsset) async {
    _log.info('Handling deletion for asset ${mediaAsset.id}.');

    final entityId = mediaAsset.associatedEntityId;
    final entityType = mediaAsset.associatedEntityType;

    if (entityId != null && entityType != null) {
      _log.info(
        'Asset ${mediaAsset.id} was associated with $entityType $entityId. Nullifying URL.',
      );
      try {
        switch (entityType) {
          case MediaAssetEntityType.user:
            final user = await _userRepository.read(id: entityId);
            // Only nullify if the URL matches the deleted asset's URL.
            // This prevents overwriting a newer image if the user has already updated their profile.
            if (user.photoUrl == mediaAsset.publicUrl) {
              await _userRepository.update(
                id: user.id,
                item: user.copyWith(photoUrl: const ValueWrapper(null)),
              );
            }
          case MediaAssetEntityType.headline:
            final headline = await _headlineRepository.read(id: entityId);
            if (headline.imageUrl == mediaAsset.publicUrl) {
              await _headlineRepository.update(
                id: headline.id,
                item: headline.copyWith(imageUrl: const ValueWrapper(null)),
              );
            }
          case MediaAssetEntityType.topic:
            final topic = await _topicRepository.read(id: entityId);
            if (topic.iconUrl == mediaAsset.publicUrl) {
              await _topicRepository.update(
                id: topic.id,
                item: topic.copyWith(iconUrl: const ValueWrapper(null)),
              );
            }
          case MediaAssetEntityType.source:
            final source = await _sourceRepository.read(id: entityId);
            if (source.logoUrl == mediaAsset.publicUrl) {
              await _sourceRepository.update(
                id: source.id,
                item: source.copyWith(logoUrl: const ValueWrapper(null)),
              );
            }
        }
      } catch (e, s) {
        _log.severe('Failed to nullify URL on parent entity $entityId.', e, s);
      }
    }

    await _mediaAssetRepository.delete(id: mediaAsset.id);
    _log.info('Deleted MediaAsset record ${mediaAsset.id} from database.');
  }

  Future<void> _cleanupOldAsset(String? oldUrl) async {
    if (oldUrl == null) return;
    unawaited(
      cleanupMediaAssetByUrl(
        url: oldUrl,
        mediaAssetRepository: _mediaAssetRepository,
        storageService: _storageService,
      ).catchError((Object e, StackTrace s) {
        _log.severe('Asset cleanup failed.', e, s);
      }),
    );
  }
}
