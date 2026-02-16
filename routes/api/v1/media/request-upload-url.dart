import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/storage/i_storage_service.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:path/path.dart' as p;

final _log = Logger('RequestUploadUrlRoute');

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final user = context.read<User>();
  return _post(context, user);
}

Future<Response> _post(RequestContext context, User user) async {
  final storageService = context.read<IStorageService>();
  final mediaAssetRepository = context.read<DataRepository<MediaAsset>>();
  final permissionService = context.read<PermissionService>();
  final request = RequestUploadUrlRequest.fromJson(
    await context.request.json() as Map<String, dynamic>,
  );
  final purpose = request.purpose;
  final fileName = request.fileName;
  final contentType = request.contentType;

  // --- 1. Granular, purpose-based authorization and validation ---
  late final List<String> allowedMimeTypes;
  late final int maxSizeInBytes;

  switch (purpose) {
    case MediaAssetPurpose.userProfilePhoto:
      if (user.isAnonymous) {
        throw const ForbiddenException(
          'You must have a registered account to upload a profile photo.',
        );
      }
      allowedMimeTypes = EnvironmentConfig.mediaProfilePhotoMimeTypes;
      maxSizeInBytes = EnvironmentConfig.mediaProfilePhotoMaxSizeInBytes;
    case MediaAssetPurpose.headlineImage:
      if (!permissionService.hasAnyPermission(user, {
        Permissions.headlineCreate,
        Permissions.headlineUpdate,
      })) {
        throw const ForbiddenException(
          'No permission to upload headline images.',
        );
      }
      allowedMimeTypes = EnvironmentConfig.mediaHeadlineImageMimeTypes;
      maxSizeInBytes = EnvironmentConfig.mediaHeadlineImageMaxSizeInBytes;
    case MediaAssetPurpose.topicImage:
      if (!permissionService.hasAnyPermission(user, {
        Permissions.topicCreate,
        Permissions.topicUpdate,
      })) {
        throw const ForbiddenException('No permission to upload topic images.');
      }
      allowedMimeTypes = EnvironmentConfig.mediaTopicImageMimeTypes;
      maxSizeInBytes = EnvironmentConfig.mediaTopicImageMaxSizeInBytes;
    case MediaAssetPurpose.sourceImage:
      if (!permissionService.hasAnyPermission(user, {
        Permissions.sourceCreate,
        Permissions.sourceUpdate,
      })) {
        throw const ForbiddenException(
          'No permission to upload source images.',
        );
      }
      allowedMimeTypes = EnvironmentConfig.mediaSourceImageMimeTypes;
      maxSizeInBytes = EnvironmentConfig.mediaSourceImageMaxSizeInBytes;
  }

  // --- 2. Content-Type Validation ---
  if (!allowedMimeTypes.contains(contentType)) {
    _log.warning(
      'User ${user.id} attempted to upload file with invalid content type '
      '"$contentType" for purpose "${purpose.name}". '
      'Allowed types: ${allowedMimeTypes.join(', ')}.',
    );
    throw InvalidInputException(
      'Invalid file type. Only ${allowedMimeTypes.join(', ')} are allowed for this upload.',
    );
  }

  // Note: The file size is not available at this stage. The size limit
  // (`maxSizeInBytes`) will be passed to the storage service, which will
  // include it in the signed policy. Google Cloud Storage will then enforce
  // this limit at the time of upload, rejecting any file that is too large.

  // --- 3. Create MediaAsset record and generate signed policy ---
  final extension = p.extension(fileName);
  final newFileName = '${ObjectId().oid}$extension';
  final storagePath = 'user-media/${user.id}/$newFileName';

  _log.info(
    'User ${user.id} requesting upload URL for purpose "${purpose.name}" '
    'with path "$storagePath".',
  );

  final mediaAsset = MediaAsset(
    id: ObjectId().oid,
    userId: user.id,
    purpose: purpose,
    status: MediaAssetStatus.pendingUpload,
    storagePath: storagePath,
    contentType: contentType,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  await mediaAssetRepository.create(item: mediaAsset);

  final uploadData = await storageService.generateUploadUrl(
    storagePath: storagePath,
    contentType: contentType,
    maxSizeInBytes: maxSizeInBytes,
  );

  return Response.json(
    body: {
      ...uploadData,
      'mediaAssetId': mediaAsset.id,
    },
  );
}
