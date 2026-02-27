import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/util/converters/date_time_converter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'local_upload_token.g.dart';

/// {@template local_upload_token}
/// A short-lived, single-use token that authorizes a file upload for a
/// specific media asset when using the local storage provider.
///
/// This is used by the `LocalStorageService` to implement the two-step upload
/// contract without exposing long-lived credentials.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class LocalUploadToken extends Equatable {
  /// {@macro local_upload_token}
  const LocalUploadToken({
    required this.id,
    required this.mediaAssetId,
    required this.createdAt,
  });

  /// Creates a [LocalUploadToken] from JSON data.
  factory LocalUploadToken.fromJson(Map<String, dynamic> json) =>
      _$LocalUploadTokenFromJson(json);

  /// The unique identifier for the token itself (e.g., a UUID).
  final String id;

  /// The ID of the [MediaAsset] this token is authorized to upload.
  final String mediaAssetId;

  /// The timestamp when this token was created.
  /// This is used by MongoDB's TTL index to automatically expire the token.
  @DateTimeConverter()
  final DateTime createdAt;

  /// Converts this [LocalUploadToken] instance to JSON data.
  Map<String, dynamic> toJson() => _$LocalUploadTokenToJson(this);

  @override
  List<Object> get props => [id, mediaAssetId, createdAt];
}
