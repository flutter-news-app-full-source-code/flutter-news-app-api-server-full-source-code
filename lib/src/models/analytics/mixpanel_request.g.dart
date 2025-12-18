// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mixpanel_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MixpanelSegmentationRequest _$MixpanelSegmentationRequestFromJson(
  Map<String, dynamic> json,
) => MixpanelSegmentationRequest(
  projectId: json['project_id'] as String,
  event: json['event'] as String,
  fromDate: json['from_date'] as String,
  toDate: json['to_date'] as String,
  unit:
      $enumDecodeNullable(_$MixpanelTimeUnitEnumMap, json['unit']) ??
      MixpanelTimeUnit.day,
);

Map<String, dynamic> _$MixpanelSegmentationRequestToJson(
  MixpanelSegmentationRequest instance,
) => <String, dynamic>{
  'project_id': instance.projectId,
  'event': instance.event,
  'from_date': instance.fromDate,
  'to_date': instance.toDate,
  'unit': _$MixpanelTimeUnitEnumMap[instance.unit]!,
};

const _$MixpanelTimeUnitEnumMap = {
  MixpanelTimeUnit.hour: 'hour',
  MixpanelTimeUnit.day: 'day',
  MixpanelTimeUnit.week: 'week',
  MixpanelTimeUnit.month: 'month',
};

MixpanelTopEventsRequest _$MixpanelTopEventsRequestFromJson(
  Map<String, dynamic> json,
) => MixpanelTopEventsRequest(
  projectId: json['project_id'] as String,
  event: json['event'] as String,
  name: json['name'] as String,
  fromDate: json['from_date'] as String,
  toDate: json['to_date'] as String,
  limit: (json['limit'] as num).toInt(),
);

Map<String, dynamic> _$MixpanelTopEventsRequestToJson(
  MixpanelTopEventsRequest instance,
) => <String, dynamic>{
  'project_id': instance.projectId,
  'event': instance.event,
  'name': instance.name,
  'from_date': instance.fromDate,
  'to_date': instance.toDate,
  'limit': instance.limit,
};
