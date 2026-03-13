import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:veritai_api/src/models/ingestion/aggregator_type.dart';

part 'ingestion_topic_mapping.g.dart';

/// {@template ingestion_topic_mapping}
/// A data model representing the mapping between an external provider's
/// category string and an internal system Topic ID.
/// {@endtemplate}
@JsonSerializable(explicitToJson: true, checked: true, includeIfNull: true)
class IngestionTopicMapping extends Equatable {
  /// {@macro ingestion_topic_mapping}
  const IngestionTopicMapping({
    required this.id,
    required this.provider,
    required this.externalValue,
    required this.internalTopicId,
    required this.createdAt,
  });

  /// Creates an [IngestionTopicMapping] from JSON.
  factory IngestionTopicMapping.fromJson(Map<String, dynamic> json) =>
      _$IngestionTopicMappingFromJson(json);

  /// The unique identifier for this mapping record.
  final String id;

  /// The aggregator provider this mapping applies to.
  final AggregatorType provider;

  /// The raw category string returned by the provider.
  final String externalValue;

  /// The ID of the internal [Topic] this maps to.
  final String internalTopicId;

  /// The creation timestamp.
  final DateTime createdAt;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$IngestionTopicMappingToJson(this);

  @override
  List<Object?> get props => [id, provider, externalValue, internalTopicId];
}
