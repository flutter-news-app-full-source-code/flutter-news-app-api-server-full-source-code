// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aggregator_source_mapping.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AggregatorSourceMapping _$AggregatorSourceMappingFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AggregatorSourceMapping', json, ($checkedConvert) {
  final val = AggregatorSourceMapping(
    id: $checkedConvert('id', (v) => v as String),
    sourceId: $checkedConvert('sourceId', (v) => v as String),
    aggregatorType: $checkedConvert(
      'aggregatorType',
      (v) => $enumDecode(_$AggregatorTypeEnumMap, v),
    ),
    externalId: $checkedConvert('externalId', (v) => v as String),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    isEnabled: $checkedConvert('isEnabled', (v) => v as bool? ?? true),
  );
  return val;
});

Map<String, dynamic> _$AggregatorSourceMappingToJson(
  AggregatorSourceMapping instance,
) => <String, dynamic>{
  'id': instance.id,
  'sourceId': instance.sourceId,
  'aggregatorType': _$AggregatorTypeEnumMap[instance.aggregatorType]!,
  'externalId': instance.externalId,
  'isEnabled': instance.isEnabled,
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$AggregatorTypeEnumMap = {
  AggregatorType.newsApi: 'newsApi',
  AggregatorType.mediaStack: 'mediaStack',
};
