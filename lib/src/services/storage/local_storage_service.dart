import 'dart:async';
import 'dart:io';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/storage/local_upload_token.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/storage/i_storage_service.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:path/path.dart' as p;

/// {@template local_storage_service}
/// A concrete implementation of [IStorageService] that saves files to the
/// local server filesystem.
/// {@endtemplate}
class LocalStorageService implements IStorageService {
  /// {@macro local_storage_service}
  LocalStorageService({
    required DataRepository<LocalUploadToken> uploadTokenRepository,
    required DataRepository<MediaAsset> mediaAssetRepository,
    required Logger log,
  }) : _uploadTokenRepository = uploadTokenRepository,
       _mediaAssetRepository = mediaAssetRepository,
       _log = log;

  final DataRepository<LocalUploadToken> _uploadTokenRepository;
  final DataRepository<MediaAsset> _mediaAssetRepository;
  final Logger _log;

  @override
  Future<Map<String, dynamic>> generateUploadUrl({
    required String storagePath,
    required String contentType,
    required int maxSizeInBytes,
  }) async {
    _log.info(
      'Generating local upload token for storage path: "$storagePath".',
    );

    // 1. Find the MediaAsset record that was just created for this upload.
    final assets = await _mediaAssetRepository.readAll(
      filter: {'storagePath': storagePath},
      pagination: const PaginationOptions(limit: 1),
    );
    if (assets.items.isEmpty) {
      _log.severe(
        'Consistency error: Could not find MediaAsset for storage path "$storagePath" when generating upload token.',
      );
      throw const ServerException(
        'Failed to find associated media asset for upload.',
      );
    }
    final mediaAsset = assets.items.first;

    // 2. Create a single-use upload token.
    final token = LocalUploadToken(
      id: ObjectId().oid,
      mediaAssetId: mediaAsset.id,
      createdAt: DateTime.now().toUtc(),
    );

    await _uploadTokenRepository.create(item: token);
    _log.info(
      'Created upload token ${token.id} for media asset ${mediaAsset.id}.',
    );

    // 3. Return the response structure that fulfills the upload contract.
    final response = {
      'url': '${EnvironmentConfig.apiBaseUrl}/api/v1/media/upload-local',
      'fields': {
        'key': storagePath,
        'Content-Type': contentType,
        'upload_token': token.id,
      },
    };

    return response;
  }

  @override
  Future<void> deleteObject({required String storagePath}) async {
    final basePath = EnvironmentConfig.localStoragePath;
    if (basePath == null) {
      _log.severe('LOCAL_STORAGE_PATH is not configured.');
      throw const ServerException('Local storage path is not configured.');
    }

    // Security: Prevent path traversal attacks.
    // Normalize the path and check if it is still within the configured base path.
    final safePath = p.normalize(p.join(basePath, storagePath));
    if (!p.isWithin(basePath, safePath)) {
      _log.warning(
        'Attempted to delete file outside of storage path: "$storagePath"',
      );
      throw const ForbiddenException('Invalid file path for deletion.');
    }

    _log.info('Attempting to delete local file: "$safePath"');

    try {
      final file = File(safePath);
      if (file.existsSync()) {
        file.deleteSync();
        _log.info('Successfully deleted local file: "$safePath"');
      } else {
        _log.warning('Local file not found for deletion: "$safePath"');
      }
    } on FileSystemException catch (e, s) {
      _log.severe('Failed to delete local file: "$safePath"', e, s);
      // We do not rethrow here. The cleanup worker should be able to proceed
      // with deleting the DB record even if the file deletion fails.
    }
  }
}
