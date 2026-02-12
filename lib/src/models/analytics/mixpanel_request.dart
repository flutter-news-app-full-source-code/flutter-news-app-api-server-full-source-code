import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mixpanel_request.g.dart';

/// The time unit for segmenting data in Mixpanel.
enum MixpanelTimeUnit {
  /// Segment data by the hour.
  hour,

  /// Segment data by the day.
  day,

  /// Segment data by the week.
  week,

  /// Segment data by the month.
  month,
}

/// {@template mixpanel_segmentation_request}
/// Represents the query parameters for a Mixpanel segmentation request.
/// {@endtemplate}
@JsonSerializable(
  fieldRename: FieldRename.snake,
  explicitToJson: true,
  includeIfNull: false,
  checked: true,
)
class MixpanelSegmentationRequest extends Equatable {
  /// {@macro mixpanel_segmentation_request}
  const MixpanelSegmentationRequest({
    required this.projectId,
    required this.event,
    required this.fromDate,
    required this.toDate,
    this.unit,
    this.where,
  });

  /// Creates a [MixpanelSegmentationRequest] from a JSON object.
  factory MixpanelSegmentationRequest.fromJson(Map<String, dynamic> json) =>
      _$MixpanelSegmentationRequestFromJson(json);

  /// The ID of the Mixpanel project.
  final String projectId;

  /// The name of the event to segment.
  final String event;

  /// The start date in 'YYYY-MM-DD' format.
  final String fromDate;

  /// The end date in 'YYYY-MM-DD' format.
  final String toDate;

  /// The time unit for segmentation (e.g., 'day', 'week').
  final MixpanelTimeUnit? unit;

  /// An expression to filter events by properties.
  /// See: https://developer.mixpanel.com/reference/segmentation#propexpr
  final String? where;

  /// Converts this instance to a JSON map for query parameters.
  Map<String, dynamic> toJson() => _$MixpanelSegmentationRequestToJson(this);

  @override
  List<Object?> get props => [projectId, event, fromDate, toDate, unit, where];
}

/// {@template mixpanel_top_events_request}
/// Represents the query parameters for a Mixpanel top events/properties request.
/// {@endtemplate}
@JsonSerializable(fieldRename: FieldRename.snake)
class MixpanelTopEventsRequest extends Equatable {
  /// {@macro mixpanel_top_events_request}
  const MixpanelTopEventsRequest({
    required this.projectId,
    required this.event,
    required this.name,
    required this.fromDate,
    required this.toDate,
    required this.limit,
  });

  /// Creates a [MixpanelTopEventsRequest] from a JSON object.
  factory MixpanelTopEventsRequest.fromJson(Map<String, dynamic> json) =>
      _$MixpanelTopEventsRequestFromJson(json);

  /// The ID of the Mixpanel project.
  final String projectId;

  /// The name of the event to analyze.
  final String event;

  /// The name of the property to get top values for.
  final String name;

  /// The start date in 'YYYY-MM-dd' format.
  final String fromDate;

  /// The end date in 'YYYY-MM-dd' format.
  final String toDate;

  /// The maximum number of property values to return.
  final int limit;

  /// Converts this instance to a JSON map for query parameters.
  Map<String, dynamic> toJson() => _$MixpanelTopEventsRequestToJson(this);

  @override
  List<Object> get props => [projectId, event, name, fromDate, toDate, limit];
}
