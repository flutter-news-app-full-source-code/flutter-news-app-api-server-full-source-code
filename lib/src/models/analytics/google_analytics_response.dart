import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'google_analytics_response.g.dart';

/// {@template run_report_response}
/// Represents the response from the Google Analytics Data API's `runReport`.
/// {@endtemplate}
@JsonSerializable(
  explicitToJson: true,
  createToJson: false,
  checked: true,
)
class RunReportResponse extends Equatable {
  /// {@macro run_report_response}
  const RunReportResponse({this.rows});

  /// Creates a [RunReportResponse] from JSON data.
  factory RunReportResponse.fromJson(Map<String, dynamic> json) =>
      _$RunReportResponseFromJson(json);

  /// The data rows from the report. Can be null if no data is returned.
  final List<GARow>? rows;

  @override
  List<Object?> get props => [rows];
}

/// {@template ga_row}
/// Represents a single row of data in a Google Analytics report.
/// {@endtemplate}
@JsonSerializable(
  explicitToJson: true,
  createToJson: false,
  checked: true,
)
class GARow extends Equatable {
  /// {@macro ga_row}
  const GARow({required this.metricValues, required this.dimensionValues});

  /// Creates a [GARow] from JSON data.
  factory GARow.fromJson(Map<String, dynamic> json) => _$GARowFromJson(json);

  /// The values of the dimensions in this row.
  @JsonKey(defaultValue: [])
  final List<GADimensionValue> dimensionValues;

  /// The values of the metrics in this row.
  final List<GAMetricValue> metricValues;

  @override
  List<Object> get props => [dimensionValues, metricValues];
}

/// {@template ga_dimension_value}
/// Represents the value of a single dimension.
/// {@endtemplate}
@JsonSerializable(
  explicitToJson: true,
  createToJson: false,
  checked: true,
)
class GADimensionValue extends Equatable {
  /// {@macro ga_dimension_value}
  const GADimensionValue({this.value});

  /// Creates a [GADimensionValue] from JSON data.
  factory GADimensionValue.fromJson(Map<String, dynamic> json) =>
      _$GADimensionValueFromJson(json);

  /// The string value of the dimension.
  final String? value;

  @override
  List<Object?> get props => [value];
}

/// {@template ga_metric_value}
/// Represents the value of a single metric.
/// {@endtemplate}
@JsonSerializable(
  explicitToJson: true,
  createToJson: false,
  checked: true,
)
class GAMetricValue extends Equatable {
  /// {@macro ga_metric_value}
  const GAMetricValue({this.value});

  /// Creates a [GAMetricValue] from JSON data.
  factory GAMetricValue.fromJson(Map<String, dynamic> json) =>
      _$GAMetricValueFromJson(json);

  /// The numeric value of the metric.
  ///
  /// It's a string in the API response, so it needs to be parsed.
  final String? value;

  @override
  List<Object?> get props => [value];
}
