// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mixpanel_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$MixpanelSegmentationRequestToJson(
  MixpanelSegmentationRequest instance,
) => <String, dynamic>{
  'stringify': instance.stringify,
  'hashCode': instance.hashCode,
  'project_id': instance.projectId,
  'event': instance.event,
  'from_date': instance.fromDate,
  'to_date': instance.toDate,
  'unit': _$MixpanelTimeUnitEnumMap[instance.unit]!,
  'props': instance.props,
};

const _$MixpanelTimeUnitEnumMap = {
  MixpanelTimeUnit.hour: 'hour',
  MixpanelTimeUnit.day: 'day',
  MixpanelTimeUnit.week: 'week',
  MixpanelTimeUnit.month: 'month',
};

Map<String, dynamic> _$MixpanelTopEventsRequestToJson(
  MixpanelTopEventsRequest instance,
) => <String, dynamic>{
  'stringify': instance.stringify,
  'hashCode': instance.hashCode,
  'project_id': instance.projectId,
  'event': instance.event,
  'name': instance.name,
  'from_date': instance.fromDate,
  'to_date': instance.toDate,
  'limit': instance.limit,
  'props': instance.props,
};
