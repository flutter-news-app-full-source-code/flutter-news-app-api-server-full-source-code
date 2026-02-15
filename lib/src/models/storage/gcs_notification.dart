import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'gcs_notification.g.dart';

/// {@template gcs_notification}
/// Represents the top-level payload sent by Google Cloud Pub/Sub for a
/// Cloud Storage notification.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, createToJson: false, checked: true)
class GcsNotification extends Equatable {
  /// {@macro gcs_notification}
  const GcsNotification({required this.message});

  /// Creates a [GcsNotification] from JSON data.
  factory GcsNotification.fromJson(Map<String, dynamic> json) =>
      _$GcsNotificationFromJson(json);

  /// The core message data of the notification.
  final GcsMessage message;

  @override
  List<Object> get props => [message];
}

/// {@template gcs_message}
/// Represents the 'message' object within a GCS notification.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, createToJson: false, checked: true)
class GcsMessage extends Equatable {
  /// {@macro gcs_message}
  const GcsMessage({required this.messageId, required this.attributes});

  /// Creates a [GcsMessage] from JSON data.
  factory GcsMessage.fromJson(Map<String, dynamic> json) =>
      _$GcsMessageFromJson(json);

  /// The unique identifier for this message, used for idempotency.
  final String messageId;

  /// The attributes of the message, containing the event details.
  final GcsMessageAttributes attributes;

  @override
  List<Object> get props => [messageId, attributes];
}

/// {@template gcs_message_attributes}
/// Represents the 'attributes' object within a GCS notification message.
/// {@endtemplate}
@immutable
@JsonSerializable(createToJson: false, checked: true)
class GcsMessageAttributes extends Equatable {
  /// {@macro gcs_message_attributes}
  const GcsMessageAttributes({required this.eventType, required this.objectId});

  /// Creates a [GcsMessageAttributes] from JSON data.
  factory GcsMessageAttributes.fromJson(Map<String, dynamic> json) =>
      _$GcsMessageAttributesFromJson(json);

  /// The type of event that occurred (e.g., 'OBJECT_FINALIZE').
  final String eventType;

  /// The full path to the object in the storage bucket.
  final String objectId;

  @override
  List<Object> get props => [eventType, objectId];
}
