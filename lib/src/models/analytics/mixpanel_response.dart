import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mixpanel_response.g.dart';

/// {@template mixpanel_response}
/// A generic response wrapper for Mixpanel API calls.
/// {@endtemplate}
@JsonSerializable(
  genericArgumentFactories: true,
  explicitToJson: true,
  createToJson: false,
  checked: true,
)
class MixpanelResponse<T> extends Equatable {
  /// {@macro mixpanel_response}
  const MixpanelResponse({required this.data});

  /// Creates a [MixpanelResponse] from JSON data.
  factory MixpanelResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) => _$MixpanelResponseFromJson(json, fromJsonT);

  /// The main data payload of the response.
  final T data;

  @override
  List<Object?> get props => [data];
}

/// {@template mixpanel_segmentation_data}
/// Represents the data structure for a Mixpanel segmentation query.
/// {@endtemplate}
@JsonSerializable(
  explicitToJson: true,
  createToJson: false,
  checked: true,
)
class MixpanelSegmentationData extends Equatable {
  /// {@macro mixpanel_segmentation_data}
  const MixpanelSegmentationData({required this.series, required this.values});

  /// Creates a [MixpanelSegmentationData] from JSON data.
  factory MixpanelSegmentationData.fromJson(Map<String, dynamic> json) =>
      _$MixpanelSegmentationDataFromJson(json);

  /// A list of date strings representing the time series.
  final List<String> series;

  /// A map where keys are segment names and values are lists of metrics
  /// corresponding to the `series` dates.
  final Map<String, List<int>> values;

  @override
  List<Object> get props => [series, values];
}
