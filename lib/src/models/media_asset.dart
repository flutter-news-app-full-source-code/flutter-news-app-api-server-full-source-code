// lib/src/models/media_asset.dart
import 'package:equatable/equatable.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/media_asset_entity_type.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/media_asset_purpose.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/media_asset_status.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'media_asset.g.dart';

/// {@template media_asset}
/// Represents the metadata for an uploaded media file.
///
/// This model tracks the asset's lifecycle, from the initial upload request
/// to its final storage location and public URL. It serves as the foundation
/// for the media library.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class MediaAsset extends Equatable {
  /// {@macro media_asset}
  const MediaAsset({
    required this.id,
    required this.userId,
    required this.purpose,
    required this.status,
    required this.storagePath,
    required this.contentType,
    required this.createdAt,
    required this.updatedAt,
    this.associatedEntityId,
    this.associatedEntityType,
    this.publicUrl,
  });

  /// Creates a [MediaAsset] from JSON data.
  factory MediaAsset.fromJson(Map<String, dynamic> json) =>
      _$MediaAssetFromJson(json);

  /// The unique identifier for this media asset record.
  final String id;

  /// The ID of the user who uploaded the asset.
  final String userId;

  /// The intended use of the asset (e.g., user profile photo).
  final MediaAssetPurpose purpose;

  /// The current status in the upload lifecycle.
  final MediaAssetStatus status;

  /// The full path to the object in the cloud storage bucket
  /// (e.g., 'user-media/user-id/uuid.jpg').
  final String storagePath;

  /// The MIME type of the file (e.g., 'image/jpeg').
  final String contentType;

  /// The URL from which the asset can be publicly accessed.
  /// This is typically populated after the upload is complete.
  final String? publicUrl;

  /// The timestamp when this record was created.
  final DateTime createdAt;

  /// The timestamp when this record was last updated.
  final DateTime updatedAt;

  /// The ID of the entity this asset is associated with (e.g., a Headline ID).
  /// This is null until the asset is explicitly linked, for example, when an
  /// admin assigns an uploaded image to a headline in the dashboard.
  final String? associatedEntityId;

  /// The type of the entity this asset is associated with (e.g., 'headline').
  final MediaAssetEntityType? associatedEntityType;

  /// Converts this [MediaAsset] instance to JSON data.
  Map<String, dynamic> toJson() => _$MediaAssetToJson(this);

  @override
  List<Object?> get props => [
    id,
    userId,
    purpose,
    status,
    storagePath,
    contentType,
    publicUrl,
    createdAt,
    updatedAt,
    associatedEntityId,
    associatedEntityType,
  ];

  /// Creates a copy of this [MediaAsset] with updated values.
  MediaAsset copyWith({
    String? id,
    String? userId,
    MediaAssetPurpose? purpose,
    MediaAssetStatus? status,
    String? storagePath,
    String? contentType,
    String? publicUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? associatedEntityId,
    MediaAssetEntityType? associatedEntityType,
  }) {
    return MediaAsset(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      purpose: purpose ?? this.purpose,
      status: status ?? this.status,
      storagePath: storagePath ?? this.storagePath,
      contentType: contentType ?? this.contentType,
      publicUrl: publicUrl ?? this.publicUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      associatedEntityId: associatedEntityId ?? this.associatedEntityId,
      associatedEntityType: associatedEntityType ?? this.associatedEntityType,
    );
  }
}
