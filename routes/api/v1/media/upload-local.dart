import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/storage/local_media_finalization_job.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/idempotency_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/storage/upload_token_service.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:path/path.dart' as p;

final _log = Logger('UploadLocalRoute');

/// A dedicated endpoint for handling file uploads when using the
/// `LocalStorageService`.
///
/// This endpoint expects a `multipart/form-data` request containing the
/// `upload_token` field and the `file` part, mirroring the behavior of a
/// direct-to-cloud upload.
/// It validates the token, streams the file to disk, and finalizes the upload.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final contentTypeHeader = context.request.headers['content-type'];
  if (contentTypeHeader == null ||
      !contentTypeHeader.startsWith('multipart/form-data')) {
    throw const BadRequestException('Expected multipart/form-data request.');
  }

  final uploadTokenService = context.read<UploadTokenService>();
  final mediaAssetRepository = context.read<DataRepository<MediaAsset>>();
  final finalizationJobRepository = context
      .read<DataRepository<LocalMediaFinalizationJob>>();
  final idempotencyService = context.read<IdempotencyService>();
  final basePath = EnvironmentConfig.localStoragePath!;

  String? uploadTokenValue;
  MediaAsset? mediaAsset;
  File? file;

  try {
    final formData = await context.request.formData();
    uploadTokenValue = formData.fields['upload_token'];
    final filePart = formData.files['file'];

    if (uploadTokenValue == null || filePart == null) {
      throw const BadRequestException(
        'Missing file or upload_token field in request.',
      );
    }

    // --- Idempotency Check ---
    // Use the upload token as the idempotency key to prevent duplicate processing
    // from client retries.
    if (await idempotencyService.isEventProcessed(
      uploadTokenValue,
      scope: 'local-upload',
    )) {
      _log.info(
        'Upload for token $uploadTokenValue already processed. Acknowledging.',
      );
      return Response(statusCode: HttpStatus.noContent);
    }

    // --- Atomic Token Validation and Consumption ---
    // Use `findAndRemove` to atomically find and delete the token. This
    final uploadToken = await uploadTokenService.consumeToken(uploadTokenValue);
    if (uploadToken == null) {
      throw const UnauthorizedException('Invalid or expired upload token.');
    }

    mediaAsset = await mediaAssetRepository.read(id: uploadToken.mediaAssetId);

    if (mediaAsset.status != MediaAssetStatus.pendingUpload) {
      throw const ConflictException(
        'This upload has already been processed.',
      );
    }

    // --- File Preparation & Streaming Write ---
    final filePath = p.join(basePath, mediaAsset.storagePath);
    file = File(filePath);

    // Read the file bytes in the main isolate. A Uint8List is a sendable
    // object that can be passed to the new isolate.
    final fileBytes = await filePart.readAsBytes();

    // Offload the blocking file I/O to a separate isolate to keep the main
    // event loop responsive.
    await Isolate.run(() async {
      final parentDir = file!.parent;
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }
      await file.writeAsBytes(fileBytes);
    });

    _log.info('Successfully wrote file to: $filePath');

    // --- Asynchronous Finalization ---
    // Instead of finalizing synchronously, create a job for the background
    // worker to process. This makes the local provider architecturally
    // consistent with the webhook-based cloud providers.
    final publicUrl =
        '${EnvironmentConfig.apiBaseUrl}/media/${mediaAsset.storagePath}';
    final job = LocalMediaFinalizationJob(
      id: ObjectId().oid,
      mediaAssetId: mediaAsset.id,
      publicUrl: publicUrl,
      createdAt: DateTime.now().toUtc(),
    );
    await finalizationJobRepository.create(item: job);
    _log.info('Created finalization job ${job.id} for asset ${mediaAsset.id}.');

    // --- Record Idempotency ---
    await idempotencyService.recordEvent(
      uploadTokenValue,
      scope: 'local-upload',
    );
    return Response(statusCode: HttpStatus.noContent);
  } catch (e) {
    if (file != null && file.existsSync()) {
      file.deleteSync();
      _log.warning('Deleted partial file on error: ${file.path}');
    }
    if (mediaAsset != null) {
      unawaited(
        mediaAssetRepository.update(
          id: mediaAsset.id,
          item: mediaAsset.copyWith(status: MediaAssetStatus.failed),
        ),
      );
    }
    rethrow;
  }
}
