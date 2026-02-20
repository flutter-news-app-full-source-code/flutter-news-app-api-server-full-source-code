// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_media_finalization_job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocalMediaFinalizationJob _$LocalMediaFinalizationJobFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('LocalMediaFinalizationJob', json, ($checkedConvert) {
  final val = LocalMediaFinalizationJob(
    id: $checkedConvert('id', (v) => v as String),
    mediaAssetId: $checkedConvert('mediaAssetId', (v) => v as String),
    publicUrl: $checkedConvert('publicUrl', (v) => v as String),
    createdAt: $checkedConvert(
      'createdAt',
      (v) => const DateTimeConverter().fromJson(v as String),
    ),
  );
  return val;
});

Map<String, dynamic> _$LocalMediaFinalizationJobToJson(
  LocalMediaFinalizationJob instance,
) => <String, dynamic>{
  'id': instance.id,
  'mediaAssetId': instance.mediaAssetId,
  'publicUrl': instance.publicUrl,
  'createdAt': const DateTimeConverter().toJson(instance.createdAt),
};
