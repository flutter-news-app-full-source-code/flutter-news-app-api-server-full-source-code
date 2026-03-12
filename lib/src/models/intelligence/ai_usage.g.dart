// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_usage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiUsage _$AiUsageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AiUsage', json, ($checkedConvert) {
  final val = AiUsage(
    id: $checkedConvert('id', (v) => v as String),
    tokenUsage: $checkedConvert('tokenUsage', (v) => (v as num).toInt()),
    requestCount: $checkedConvert('requestCount', (v) => (v as num).toInt()),
    updatedAt: $checkedConvert('updatedAt', (v) => DateTime.parse(v as String)),
  );
  return val;
});

Map<String, dynamic> _$AiUsageToJson(AiUsage instance) => <String, dynamic>{
  'id': instance.id,
  'tokenUsage': instance.tokenUsage,
  'requestCount': instance.requestCount,
  'updatedAt': instance.updatedAt.toIso8601String(),
};
