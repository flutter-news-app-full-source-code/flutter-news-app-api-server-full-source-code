// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ingestion_topic_mapping.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IngestionTopicMapping _$IngestionTopicMappingFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('IngestionTopicMapping', json, ($checkedConvert) {
  final val = IngestionTopicMapping(
    id: $checkedConvert('id', (v) => v as String),
    provider: $checkedConvert(
      'provider',
      (v) => $enumDecode(_$AggregatorTypeEnumMap, v),
    ),
    externalValue: $checkedConvert('externalValue', (v) => v as String),
    internalTopicId: $checkedConvert('internalTopicId', (v) => v as String),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
  );
  return val;
});

Map<String, dynamic> _$IngestionTopicMappingToJson(
  IngestionTopicMapping instance,
) => <String, dynamic>{
  'id': instance.id,
  'provider': _$AggregatorTypeEnumMap[instance.provider]!,
  'externalValue': instance.externalValue,
  'internalTopicId': instance.internalTopicId,
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$AggregatorTypeEnumMap = {AggregatorType.newsApi: 'newsApi'};
