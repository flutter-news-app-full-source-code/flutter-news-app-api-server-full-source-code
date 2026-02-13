// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_asset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaAsset _$MediaAssetFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MediaAsset', json, ($checkedConvert) {
  final val = MediaAsset(
    id: $checkedConvert('id', (v) => v as String),
    userId: $checkedConvert('userId', (v) => v as String),
    purpose: $checkedConvert(
      'purpose',
      (v) => $enumDecode(_$MediaAssetPurposeEnumMap, v),
    ),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(_$MediaAssetStatusEnumMap, v),
    ),
    storagePath: $checkedConvert('storagePath', (v) => v as String),
    contentType: $checkedConvert('contentType', (v) => v as String),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    updatedAt: $checkedConvert('updatedAt', (v) => DateTime.parse(v as String)),
    publicUrl: $checkedConvert('publicUrl', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$MediaAssetToJson(MediaAsset instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'purpose': _$MediaAssetPurposeEnumMap[instance.purpose]!,
      'status': _$MediaAssetStatusEnumMap[instance.status]!,
      'storagePath': instance.storagePath,
      'contentType': instance.contentType,
      'publicUrl': instance.publicUrl,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$MediaAssetPurposeEnumMap = {
  MediaAssetPurpose.userProfilePhoto: 'userProfilePhoto',
  MediaAssetPurpose.headlineImage: 'headlineImage',
};

const _$MediaAssetStatusEnumMap = {
  MediaAssetStatus.pendingUpload: 'pending_upload',
  MediaAssetStatus.completed: 'completed',
  MediaAssetStatus.failed: 'failed',
};
