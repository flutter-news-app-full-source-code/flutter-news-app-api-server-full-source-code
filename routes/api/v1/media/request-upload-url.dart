import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/media_asset_purpose.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/media_asset_status.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/media_asset.dart';
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

  // Manually perform authorization for this custom route.
  // The `requireAuthentication` middleware has already ensured a user exists.
  final user = context.read<User>();
  final permissionService = context.read<PermissionService>();
  if (!permissionService.hasPermission(
    user,
    Permissions.mediaRequestUploadUrl,
  )) {
    throw const ForbiddenException(
      'You do not have permission to upload media.',
    );
  }

  return _post(context, user);
}

Future<Response> _post(RequestContext context, User user) async {
  final storageService = context.read<IStorageService>();
  final mediaAssetRepository = context.read<DataRepository<MediaAsset>>();
  final body = await context.request.json() as Map<String, dynamic>;

  final fileName = body['fileName'] as String?;
  final contentType = body['contentType'] as String?;
  final purposeString = body['purpose'] as String?;

  if (fileName == null || contentType == null || purposeString == null) {
    throw const BadRequestException(
      'Missing required fields: fileName, contentType, purpose.',
    );
  }

  final purpose = MediaAssetPurpose.values.byName(purposeString);
  final extension = p.extension(fileName);
  final newFileName = '${ObjectId().oid}$extension';
  final storagePath = 'user-media/${user.id}/$newFileName';

  _log.info(
    'User ${user.id} requesting upload URL for purpose "$purposeString" '
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

  final signedUrl = await storageService.generateUploadUrl(
    storagePath: storagePath,
    contentType: contentType,
  );

  return Response.json(
    body: {
      'signedUrl': signedUrl,
      'mediaAssetId': mediaAsset.id,
    },
  );
}
