import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'firebase_request_body.g.dart';

/// {@template firebase_request_body}
/// Represents the top-level structure for a Firebase Cloud Messaging
/// v1 API request.
/// {@endtemplate}
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class FirebaseRequestBody extends Equatable {
  /// {@macro firebase_request_body}
  const FirebaseRequestBody({required this.message});

  /// The message payload.
  final FirebaseMessage message;

  /// Converts this [FirebaseRequestBody] instance to a JSON map.
  Map<String, dynamic> toJson() => _$FirebaseRequestBodyToJson(this);

  @override
  List<Object> get props => [message];
}

/// {@template firebase_message}
/// Represents the message object within a Firebase request.
/// {@endtemplate}
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class FirebaseMessage extends Equatable {
  /// {@macro firebase_message}
  const FirebaseMessage({
    required this.token,
    required this.notification,
    required this.data,
  });

  /// The registration token of the device to send the message to.
  final String token;

  /// The notification content.
  final FirebaseNotification notification;

  /// The custom data payload.
  final Map<String, dynamic> data;

  /// Converts this [FirebaseMessage] instance to a JSON map.
  Map<String, dynamic> toJson() => _$FirebaseMessageToJson(this);

  @override
  List<Object> get props => [token, notification, data];
}

/// {@template firebase_notification}
/// Represents the notification content within a Firebase message.
/// {@endtemplate}
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class FirebaseNotification extends Equatable {
  /// {@macro firebase_notification}
  const FirebaseNotification({
    required this.title,
    required this.body,
    this.image,
  });

  /// The notification's title.
  final String title;

  /// The notification's body text.
  final String body;

  /// The URL of an image to be displayed in the notification.
  final String? image;

  /// Converts this [FirebaseNotification] instance to a JSON map.
  Map<String, dynamic> toJson() => _$FirebaseNotificationToJson(this);

  @override
  List<Object?> get props => [title, body, image];
}
