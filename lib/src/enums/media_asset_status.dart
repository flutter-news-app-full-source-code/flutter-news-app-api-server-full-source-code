// lib/src/enums/media_asset_status.dart
import 'package:json_annotation/json_annotation.dart';

/// {@template media_asset_status}
/// Defines the lifecycle status of a media asset during the upload process.
/// {@endtemplate}
@JsonEnum()
enum MediaAssetStatus {
  /// The upload has been requested, and a signed URL has been generated,
  /// but the file has not yet been uploaded to the storage provider.
  pendingUpload,

  /// The file has been successfully uploaded to the storage provider, and the
  /// webhook confirmation has been received.
  completed,

  /// The upload process failed.
  failed,
}
