import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'google_analytics_request.g.dart';

/// {@template run_report_request}
/// Represents the request body for the Google Analytics Data API's `runReport`.
/// {@endtemplate}
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class RunReportRequest extends Equatable {
  /// {@macro run_report_request}
  const RunReportRequest({
    required this.dateRanges,
    this.dimensions,
    this.metrics,
    this.dimensionFilter,
    this.limit,
  });

  /// Creates a [RunReportRequest] from JSON data.
  factory RunReportRequest.fromJson(Map<String, dynamic> json) =>
      _$RunReportRequestFromJson(json);

  /// The date ranges for which to retrieve data.
  final List<GARequestDateRange> dateRanges;

  /// The dimensions to include in the report.
  final List<GARequestDimension>? dimensions;

  /// The metrics to include in the report.
  final List<GARequestMetric>? metrics;

  /// A filter to apply to the dimensions.
  final GARequestFilterExpression? dimensionFilter;

  /// The maximum number of rows to return.
  final int? limit;

  /// Converts this [RunReportRequest] instance to JSON data.
  Map<String, dynamic> toJson() => _$RunReportRequestToJson(this);

  @override
  List<Object?> get props => [
    dateRanges,
    dimensions,
    metrics,
    dimensionFilter,
    limit,
  ];
}

/// {@template ga_request_date_range}
/// Represents a date range for a Google Analytics report request.
/// {@endtemplate}
@JsonSerializable()
class GARequestDateRange extends Equatable {
  /// {@macro ga_request_date_range}
  const GARequestDateRange({required this.startDate, required this.endDate});

  /// Creates a [GARequestDateRange] from JSON data.
  factory GARequestDateRange.fromJson(Map<String, dynamic> json) =>
      _$GARequestDateRangeFromJson(json);

  /// The start date in 'YYYY-MM-DD' format.
  final String startDate;

  /// The end date in 'YYYY-MM-DD' format.
  final String endDate;

  /// Converts this [GARequestDateRange] instance to JSON data.
  Map<String, dynamic> toJson() => _$GARequestDateRangeToJson(this);

  @override
  List<Object> get props => [startDate, endDate];
}

/// {@template ga_request_dimension}
/// Represents a dimension to include in a Google Analytics report request.
/// {@endtemplate}
@JsonSerializable()
class GARequestDimension extends Equatable {
  /// {@macro ga_request_dimension}
  const GARequestDimension({required this.name});

  /// Creates a [GARequestDimension] from JSON data.
  factory GARequestDimension.fromJson(Map<String, dynamic> json) =>
      _$GARequestDimensionFromJson(json);

  /// The name of the dimension.
  final String name;

  /// Converts this [GARequestDimension] instance to JSON data.
  Map<String, dynamic> toJson() => _$GARequestDimensionToJson(this);

  @override
  List<Object> get props => [name];
}

/// {@template ga_request_metric}
/// Represents a metric to include in a Google Analytics report request.
/// {@endtemplate}
@JsonSerializable()
class GARequestMetric extends Equatable {
  /// {@macro ga_request_metric}
  const GARequestMetric({required this.name});

  /// Creates a [GARequestMetric] from JSON data.
  factory GARequestMetric.fromJson(Map<String, dynamic> json) =>
      _$GARequestMetricFromJson(json);

  /// The name of the metric.
  final String name;

  /// Converts this [GARequestMetric] instance to JSON data.
  Map<String, dynamic> toJson() => _$GARequestMetricToJson(this);

  @override
  List<Object> get props => [name];
}

/// {@template ga_request_filter_expression}
/// Represents a filter expression for a Google Analytics report request.
/// {@endtemplate}
@JsonSerializable(explicitToJson: true)
class GARequestFilterExpression extends Equatable {
  /// {@macro ga_request_filter_expression}
  const GARequestFilterExpression({required this.filter});

  /// Creates a [GARequestFilterExpression] from JSON data.
  factory GARequestFilterExpression.fromJson(Map<String, dynamic> json) =>
      _$GARequestFilterExpressionFromJson(json);

  /// The filter to apply.
  final GARequestFilter filter;

  /// Converts this [GARequestFilterExpression] instance to JSON data.
  Map<String, dynamic> toJson() => _$GARequestFilterExpressionToJson(this);

  @override
  List<Object> get props => [filter];
}

/// {@template ga_request_filter}
/// Represents a filter for a specific field in a Google Analytics request.
/// {@endtemplate}
@JsonSerializable(explicitToJson: true)
class GARequestFilter extends Equatable {
  /// {@macro ga_request_filter}
  const GARequestFilter({required this.fieldName, required this.stringFilter});

  /// Creates a [GARequestFilter] from JSON data.
  factory GARequestFilter.fromJson(Map<String, dynamic> json) =>
      _$GARequestFilterFromJson(json);

  /// The name of the field to filter on.
  final String fieldName;

  /// The string filter to apply.
  final GARequestStringFilter stringFilter;

  /// Converts this [GARequestFilter] instance to JSON data.
  Map<String, dynamic> toJson() => _$GARequestFilterToJson(this);

  @override
  List<Object> get props => [fieldName, stringFilter];
}

/// {@template ga_request_string_filter}
/// Represents a string filter in a Google Analytics request.
/// {@endtemplate}
@JsonSerializable()
class GARequestStringFilter extends Equatable {
  /// {@macro ga_request_string_filter}
  const GARequestStringFilter({required this.value});

  /// Creates a [GARequestStringFilter] from JSON data.
  factory GARequestStringFilter.fromJson(Map<String, dynamic> json) =>
      _$GARequestStringFilterFromJson(json);

  /// The value to filter by.
  final String value;

  /// Converts this [GARequestStringFilter] instance to JSON data.
  Map<String, dynamic> toJson() => _$GARequestStringFilterToJson(this);

  @override
  List<Object> get props => [value];
}
