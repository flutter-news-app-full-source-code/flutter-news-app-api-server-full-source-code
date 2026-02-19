import 'package:equatable/equatable.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/storage/s3_notification.dart'
    show S3Notification;
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'sns_notification.g.dart';

/// {@template sns_notification}
/// Represents the top-level JSON payload sent by Amazon SNS.
/// {@endtemplate}
@immutable
@JsonSerializable(createToJson: false, checked: true)
class SnsNotification extends Equatable {
  /// {@macro sns_notification}
  const SnsNotification({
    required this.type,
    this.messageId,
    this.topicArn,
    this.message,
    this.timestamp,
    this.subscribeUrl,
  });

  /// Creates an [SnsNotification] from JSON data.
  factory SnsNotification.fromJson(Map<String, dynamic> json) =>
      _$SnsNotificationFromJson(json);

  /// The type of message (e.g., 'Notification', 'SubscriptionConfirmation').
  @JsonKey(name: 'Type')
  final String type;

  /// The unique identifier for the message.
  @JsonKey(name: 'MessageId')
  final String? messageId;

  /// The ARN of the topic this message was published to.
  @JsonKey(name: 'TopicArn')
  final String? topicArn;

  /// The payload of the message. For S3 events, this contains the JSON string
  /// of the [S3Notification].
  @JsonKey(name: 'Message')
  final String? message;

  /// The timestamp when the message was published.
  @JsonKey(name: 'Timestamp')
  final DateTime? timestamp;

  /// The URL to visit to confirm the subscription (only for SubscriptionConfirmation).
  @JsonKey(name: 'SubscribeURL')
  final String? subscribeUrl;

  @override
  List<Object?> get props => [
    type,
    messageId,
    topicArn,
    message,
    timestamp,
    subscribeUrl,
  ];
}
