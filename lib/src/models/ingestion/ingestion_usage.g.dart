// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ingestion_usage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IngestionUsage _$IngestionUsageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('IngestionUsage', json, ($checkedConvert) {
  final val = IngestionUsage(
    id: $checkedConvert('id', (v) => v as String),
    requestCount: $checkedConvert('requestCount', (v) => (v as num).toInt()),
    updatedAt: $checkedConvert('updatedAt', (v) => DateTime.parse(v as String)),
  );
  return val;
});

Map<String, dynamic> _$IngestionUsageToJson(IngestionUsage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'requestCount': instance.requestCount,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
