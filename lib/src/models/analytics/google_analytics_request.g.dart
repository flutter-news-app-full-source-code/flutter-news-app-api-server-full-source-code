// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_analytics_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RunReportRequest _$RunReportRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RunReportRequest', json, ($checkedConvert) {
  final val = RunReportRequest(
    dateRanges: $checkedConvert(
      'dateRanges',
      (v) => (v as List<dynamic>)
          .map((e) => GARequestDateRange.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    dimensions: $checkedConvert(
      'dimensions',
      (v) => (v as List<dynamic>?)
          ?.map((e) => GARequestDimension.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    metrics: $checkedConvert(
      'metrics',
      (v) => (v as List<dynamic>?)
          ?.map((e) => GARequestMetric.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    dimensionFilter: $checkedConvert(
      'dimensionFilter',
      (v) => v == null
          ? null
          : GARequestFilterExpression.fromJson(v as Map<String, dynamic>),
    ),
    limit: $checkedConvert('limit', (v) => (v as num?)?.toInt()),
  );
  return val;
});

Map<String, dynamic> _$RunReportRequestToJson(RunReportRequest instance) =>
    <String, dynamic>{
      'dateRanges': instance.dateRanges.map((e) => e.toJson()).toList(),
      'dimensions': ?instance.dimensions?.map((e) => e.toJson()).toList(),
      'metrics': ?instance.metrics?.map((e) => e.toJson()).toList(),
      'dimensionFilter': ?instance.dimensionFilter?.toJson(),
      'limit': ?instance.limit,
    };

GARequestDateRange _$GARequestDateRangeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GARequestDateRange', json, ($checkedConvert) {
      final val = GARequestDateRange(
        startDate: $checkedConvert('startDate', (v) => v as String),
        endDate: $checkedConvert('endDate', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$GARequestDateRangeToJson(GARequestDateRange instance) =>
    <String, dynamic>{
      'startDate': instance.startDate,
      'endDate': instance.endDate,
    };

GARequestDimension _$GARequestDimensionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GARequestDimension', json, ($checkedConvert) {
      final val = GARequestDimension(
        name: $checkedConvert('name', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$GARequestDimensionToJson(GARequestDimension instance) =>
    <String, dynamic>{'name': instance.name};

GARequestMetric _$GARequestMetricFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GARequestMetric', json, ($checkedConvert) {
      final val = GARequestMetric(
        name: $checkedConvert('name', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$GARequestMetricToJson(GARequestMetric instance) =>
    <String, dynamic>{'name': instance.name};

GARequestFilterExpression _$GARequestFilterExpressionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GARequestFilterExpression', json, ($checkedConvert) {
  final val = GARequestFilterExpression(
    filter: $checkedConvert(
      'filter',
      (v) => GARequestFilter.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$GARequestFilterExpressionToJson(
  GARequestFilterExpression instance,
) => <String, dynamic>{'filter': instance.filter.toJson()};

GARequestFilter _$GARequestFilterFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GARequestFilter', json, ($checkedConvert) {
      final val = GARequestFilter(
        fieldName: $checkedConvert('fieldName', (v) => v as String),
        stringFilter: $checkedConvert(
          'stringFilter',
          (v) => GARequestStringFilter.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$GARequestFilterToJson(GARequestFilter instance) =>
    <String, dynamic>{
      'fieldName': instance.fieldName,
      'stringFilter': instance.stringFilter.toJson(),
    };

GARequestStringFilter _$GARequestStringFilterFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GARequestStringFilter', json, ($checkedConvert) {
  final val = GARequestStringFilter(
    value: $checkedConvert('value', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$GARequestStringFilterToJson(
  GARequestStringFilter instance,
) => <String, dynamic>{'value': instance.value};
