// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_analytics_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RunReportResponse _$RunReportResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RunReportResponse', json, ($checkedConvert) {
      final val = RunReportResponse(
        rows: $checkedConvert(
          'rows',
          (v) => (v as List<dynamic>?)
              ?.map((e) => GARow.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

GARow _$GARowFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GARow', json, ($checkedConvert) {
      final val = GARow(
        dimensionValues: $checkedConvert(
          'dimensionValues',
          (v) =>
              (v as List<dynamic>?)
                  ?.map(
                    (e) => GADimensionValue.fromJson(e as Map<String, dynamic>),
                  )
                  .toList() ??
              [],
        ),
        metricValues: $checkedConvert(
          'metricValues',
          (v) => (v as List<dynamic>)
              .map((e) => GAMetricValue.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

GADimensionValue _$GADimensionValueFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GADimensionValue', json, ($checkedConvert) {
      final val = GADimensionValue(
        value: $checkedConvert('value', (v) => v as String?),
      );
      return val;
    });

GAMetricValue _$GAMetricValueFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GAMetricValue', json, ($checkedConvert) {
      final val = GAMetricValue(
        value: $checkedConvert('value', (v) => v as String?),
      );
      return val;
    });
