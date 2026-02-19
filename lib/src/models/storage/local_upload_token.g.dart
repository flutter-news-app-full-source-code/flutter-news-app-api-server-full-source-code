// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_upload_token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocalUploadToken _$LocalUploadTokenFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LocalUploadToken', json, ($checkedConvert) {
      final val = LocalUploadToken(
        id: $checkedConvert('id', (v) => v as String),
        mediaAssetId: $checkedConvert('mediaAssetId', (v) => v as String),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => const DateTimeConverter().fromJson(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$LocalUploadTokenToJson(LocalUploadToken instance) =>
    <String, dynamic>{
      'id': instance.id,
      'mediaAssetId': instance.mediaAssetId,
      'createdAt': const DateTimeConverter().toJson(instance.createdAt),
    };
