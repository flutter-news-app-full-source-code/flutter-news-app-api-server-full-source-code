import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:veritai_api/src/config/config.dart' show EnvironmentConfig;
import 'package:veritai_api/src/config/environment_config.dart'
    show EnvironmentConfig;

part 'ai_usage.g.dart';

/// {@template ai_usage}
/// Internal model for tracking AI consumption and cost governance.
///
/// This model is used to enforce the [EnvironmentConfig.aiDailyTokenQuota]
/// by persisting daily consumption metrics in a local collection.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, checked: true, includeIfNull: true)
class AiUsage extends Equatable {
  /// {@macro ai_usage}
  const AiUsage({
    required this.id,
    required this.tokenUsage,
    required this.requestCount,
    required this.updatedAt,
  });

  /// Creates an [AiUsage] from JSON data.
  factory AiUsage.fromJson(Map<String, dynamic> json) =>
      _$AiUsageFromJson(json);

  /// The unique identifier, typically a date-based hash (e.g., 2024-03-12).
  final String id;

  /// Total tokens consumed (Prompt + Completion).
  final int tokenUsage;

  /// Total successful requests made to the AI provider.
  final int requestCount;

  /// The last time this record was incremented.
  final DateTime updatedAt;

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$AiUsageToJson(this);

  /// Creates a copy with updated fields.
  AiUsage copyWith({
    String? id,
    int? tokenUsage,
    int? requestCount,
    DateTime? updatedAt,
  }) {
    return AiUsage(
      id: id ?? this.id,
      tokenUsage: tokenUsage ?? this.tokenUsage,
      requestCount: requestCount ?? this.requestCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, tokenUsage, requestCount, updatedAt];
}
