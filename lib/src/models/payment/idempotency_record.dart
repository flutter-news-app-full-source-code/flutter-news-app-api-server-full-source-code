import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'idempotency_record.g.dart';

/// {@template idempotency_record}
/// Represents a processed event or transaction to ensure idempotency.
///
/// This record is stored in the database with a TTL (Time-To-Live) index.
/// If a record with the same [id] exists, it means the event has already
/// been processed.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class IdempotencyRecord extends Equatable {
  /// {@macro idempotency_record}
  const IdempotencyRecord({
    required this.id,
    required this.createdAt,
  });

  /// Creates an [IdempotencyRecord] from JSON data.
  factory IdempotencyRecord.fromJson(Map<String, dynamic> json) =>
      _$IdempotencyRecordFromJson(json);

  /// The unique identifier for the event (e.g., transactionId, eventId).
  /// This maps to the `_id` field in MongoDB.
  @JsonKey(name: '_id')
  final String id;

  /// The timestamp when this record was created (processed).
  @DateTimeConverter()
  final DateTime createdAt;

  /// Converts this [IdempotencyRecord] instance to JSON data.
  Map<String, dynamic> toJson() => _$IdempotencyRecordToJson(this);

  @override
  List<Object?> get props => [id, createdAt];
}
