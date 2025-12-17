// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_analytics_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RunReportRequest _$RunReportRequestFromJson(Map<String, dynamic> json) =>
    RunReportRequest(
      dateRanges: (json['dateRanges'] as List<dynamic>)
          .map((e) => GARequestDateRange.fromJson(e as Map<String, dynamic>))
          .toList(),
      dimensions: (json['dimensions'] as List<dynamic>?)
          ?.map((e) => GARequestDimension.fromJson(e as Map<String, dynamic>))
          .toList(),
      metrics: (json['metrics'] as List<dynamic>?)
          ?.map((e) => GARequestMetric.fromJson(e as Map<String, dynamic>))
          .toList(),
      dimensionFilter: json['dimensionFilter'] == null
          ? null
          : GARequestFilterExpression.fromJson(
              json['dimensionFilter'] as Map<String, dynamic>,
            ),
      limit: (json['limit'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RunReportRequestToJson(RunReportRequest instance) =>
    <String, dynamic>{
      'dateRanges': instance.dateRanges.map((e) => e.toJson()).toList(),
      'dimensions': ?instance.dimensions?.map((e) => e.toJson()).toList(),
      'metrics': ?instance.metrics?.map((e) => e.toJson()).toList(),
      'dimensionFilter': ?instance.dimensionFilter?.toJson(),
      'limit': ?instance.limit,
    };

GARequestDateRange _$GARequestDateRangeFromJson(Map<String, dynamic> json) =>
    GARequestDateRange(
      startDate: json['startDate'] as String,
      endDate: json['endDate'] as String,
    );

Map<String, dynamic> _$GARequestDateRangeToJson(GARequestDateRange instance) =>
    <String, dynamic>{
      'startDate': instance.startDate,
      'endDate': instance.endDate,
    };

GARequestDimension _$GARequestDimensionFromJson(Map<String, dynamic> json) =>
    GARequestDimension(name: json['name'] as String);

Map<String, dynamic> _$GARequestDimensionToJson(GARequestDimension instance) =>
    <String, dynamic>{'name': instance.name};

GARequestMetric _$GARequestMetricFromJson(Map<String, dynamic> json) =>
    GARequestMetric(name: json['name'] as String);

Map<String, dynamic> _$GARequestMetricToJson(GARequestMetric instance) =>
    <String, dynamic>{'name': instance.name};

GARequestFilterExpression _$GARequestFilterExpressionFromJson(
  Map<String, dynamic> json,
) => GARequestFilterExpression(
  filter: GARequestFilter.fromJson(json['filter'] as Map<String, dynamic>),
);

Map<String, dynamic> _$GARequestFilterExpressionToJson(
  GARequestFilterExpression instance,
) => <String, dynamic>{'filter': instance.filter.toJson()};

GARequestFilter _$GARequestFilterFromJson(Map<String, dynamic> json) =>
    GARequestFilter(
      fieldName: json['fieldName'] as String,
      stringFilter: GARequestStringFilter.fromJson(
        json['stringFilter'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$GARequestFilterToJson(GARequestFilter instance) =>
    <String, dynamic>{
      'fieldName': instance.fieldName,
      'stringFilter': instance.stringFilter.toJson(),
    };

GARequestStringFilter _$GARequestStringFilterFromJson(
  Map<String, dynamic> json,
) => GARequestStringFilter(value: json['value'] as String);

Map<String, dynamic> _$GARequestStringFilterToJson(
  GARequestStringFilter instance,
) => <String, dynamic>{'value': instance.value};
