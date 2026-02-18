import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 's3_notification.g.dart';

/// {@template s3_notification}
/// Represents the event payload sent by AWS S3 (or wrapped in an SNS Message).
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, createToJson: false, checked: true)
class S3Notification extends Equatable {
  /// {@macro s3_notification}
  const S3Notification({required this.records});

  /// Creates an [S3Notification] from JSON data.
  factory S3Notification.fromJson(Map<String, dynamic> json) =>
      _$S3NotificationFromJson(json);

  /// The list of event records.
  @JsonKey(name: 'Records')
  final List<S3Record> records;

  @override
  List<Object?> get props => [records];
}

/// {@template s3_record}
/// Represents a single event record within an S3 notification.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, createToJson: false, checked: true)
class S3Record extends Equatable {
  /// {@macro s3_record}
  const S3Record({
    required this.eventName,
    required this.s3,
    this.eventSource,
    this.awsRegion,
    this.eventTime,
  });

  /// Creates an [S3Record] from JSON data.
  factory S3Record.fromJson(Map<String, dynamic> json) =>
      _$S3RecordFromJson(json);

  /// The name of the event (e.g., 'ObjectCreated:Put').
  final String eventName;

  /// The S3 entity details.
  final S3Entity s3;

  /// The source of the event (e.g., 'aws:s3').
  final String? eventSource;

  /// The AWS region where the event occurred.
  final String? awsRegion;

  /// The time the event occurred.
  final DateTime? eventTime;

  @override
  List<Object?> get props => [eventName, s3, eventSource, awsRegion, eventTime];
}

/// {@template s3_entity}
/// Represents the S3 specific details in an event record.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, createToJson: false, checked: true)
class S3Entity extends Equatable {
  /// {@macro s3_entity}
  const S3Entity({required this.object});

  /// Creates an [S3Entity] from JSON data.
  factory S3Entity.fromJson(Map<String, dynamic> json) =>
      _$S3EntityFromJson(json);

  /// The object affected by the event.
  final S3Object object;

  @override
  List<Object?> get props => [object];
}

/// {@template s3_object}
/// Represents the object details in an S3 event.
/// {@endtemplate}
@immutable
@JsonSerializable(createToJson: false, checked: true)
class S3Object extends Equatable {
  /// {@macro s3_object}
  const S3Object({required this.key});

  /// Creates an [S3Object] from JSON data.
  factory S3Object.fromJson(Map<String, dynamic> json) =>
      _$S3ObjectFromJson(json);

  /// The object key. Note: This is URL-encoded.
  final String key;

  /// Returns the URL-decoded key.
  String get decodedKey => Uri.decodeFull(key);

  @override
  List<Object?> get props => [key];
}
