import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'ingestion_usage.g.dart';

/// {@template ingestion_usage}
/// Tracks the API usage for a specific day to enforce global quotas.
///
/// The [id] should be formatted as 'usage_YYYY-MM-DD'.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, checked: true, includeIfNull: true)
class IngestionUsage extends Equatable {
  /// {@macro ingestion_usage}
  const IngestionUsage({
    required this.id,
    required this.requestCount,
    required this.updatedAt,
  });

  /// Creates an [IngestionUsage] from JSON.
  factory IngestionUsage.fromJson(Map<String, dynamic> json) =>
      _$IngestionUsageFromJson(json);

  /// The unique identifier, typically 'usage_YYYY-MM-DD'.
  final String id;

  /// The number of requests made to external aggregators on this day.
  final int requestCount;

  /// The last time this record was updated.
  final DateTime updatedAt;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$IngestionUsageToJson(this);

  @override
  List<Object?> get props => [id, requestCount, updatedAt];
}
