import 'package:core/core.dart' show Source;
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:verity_api/src/models/ingestion/aggregator_type.dart';

part 'aggregator_source_mapping.g.dart';

/// {@template aggregator_source_mapping}
/// Persists the relationship between an internal [Source] and an external
/// provider's unique identifier.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, checked: true, includeIfNull: true)
class AggregatorSourceMapping extends Equatable {
  /// {@macro aggregator_source_mapping}
  const AggregatorSourceMapping({
    required this.id,
    required this.sourceId,
    required this.aggregatorType,
    required this.externalId,
    required this.createdAt, this.isEnabled = true,
  });

  /// Creates an [AggregatorSourceMapping] from JSON.
  factory AggregatorSourceMapping.fromJson(Map<String, dynamic> json) =>
      _$AggregatorSourceMappingFromJson(json);

  /// Unique identifier (MongoDB ObjectId).
  final String id;

  /// The internal ID of the [Source] entity.
  final String sourceId;

  /// The provider this mapping belongs to (e.g., newsApi).
  final AggregatorType aggregatorType;

  /// The ID used by the external provider (e.g., 'bbc-news').
  final String externalId;

  /// Whether this mapping is active. Set to false if the provider rejects it.
  final bool isEnabled;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$AggregatorSourceMappingToJson(this);

  @override
  List<Object?> get props => [
    id,
    sourceId,
    aggregatorType,
    externalId,
    isEnabled,
  ];
}
