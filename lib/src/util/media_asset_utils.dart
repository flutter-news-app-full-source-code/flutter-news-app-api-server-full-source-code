import 'dart:async';

import 'package:core/core.dart';

import 'package:flutter_news_app_api_server_full_source_code/src/services/storage/i_storage_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('MediaAssetUtils');

/// A utility function to clean up an old media asset based on its public URL.
///
/// This is used when an entity's media is updated or when the entity itself
/// is deleted, ensuring its associated media is also removed.
Future<void> cleanupMediaAssetByUrl({
  required String? url,
  required DataRepository<MediaAsset> mediaAssetRepository,
  required IStorageService storageService,
}) async {
  if (url == null || url.isEmpty) {
    return; // No old asset to clean up.
  }

  // Find the old MediaAsset by its publicUrl.
  final oldAssets = await mediaAssetRepository.readAll(
    filter: {'publicUrl': url},
    pagination: const PaginationOptions(limit: 1),
  );

  if (oldAssets.items.isEmpty) {
    _log.warning('Could not find MediaAsset to clean up for URL: $url');
    return;
  }

  final oldAsset = oldAssets.items.first;
  _log.info('Found asset ${oldAsset.id} to clean up for URL: $url');

  // Delete the file from cloud storage and then the database record.
  // This is a fire-and-forget operation; we log errors but don't rethrow.
  await storageService.deleteObject(storagePath: oldAsset.storagePath);
  await mediaAssetRepository.delete(id: oldAsset.id);
  _log.info('Cleaned up asset: ${oldAsset.id}');
}
