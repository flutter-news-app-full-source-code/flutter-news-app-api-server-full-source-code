import 'package:equatable/equatable.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/payment/payment.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'apple_notification_payload.g.dart';

/// {@template apple_notification_payload}
/// Represents the decoded payload of an Apple App Store Server Notification V2.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class AppleNotificationPayload extends Equatable {
  /// {@macro apple_notification_payload}
  const AppleNotificationPayload({
    required this.notificationType,
    this.subtype,
    required this.notificationUUID,
    required this.data,
    required this.version,
    required this.signedDate,
  });

  /// Creates an [AppleNotificationPayload] from JSON data.
  factory AppleNotificationPayload.fromJson(Map<String, dynamic> json) =>
      _$AppleNotificationPayloadFromJson(json);

  /// The type of notification.
  final AppleNotificationType notificationType;

  /// The subtype of the notification.
  final AppleNotificationSubtype? subtype;

  /// The unique identifier for this notification.
  final String notificationUUID;

  /// The data object containing the signed transaction and renewal info.
  final AppleNotificationData data;

  /// The version of the notification.
  final String version;

  /// The date the notification was signed.
  @JsonKey(fromJson: _dateTimeFromMilliseconds, toJson: _dateTimeToMilliseconds)
  final DateTime signedDate;

  /// Converts this [AppleNotificationPayload] instance to JSON data.
  Map<String, dynamic> toJson() => _$AppleNotificationPayloadToJson(this);

  @override
  List<Object?> get props => [
        notificationType,
        subtype,
        notificationUUID,
        data,
        version,
        signedDate,
      ];
}

/// {@template apple_notification_data}
/// Contains the signed transaction and renewal information.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class AppleNotificationData extends Equatable {
  /// {@macro apple_notification_data}
  const AppleNotificationData({
    required this.signedTransactionInfo,
    required this.signedRenewalInfo,
    required this.bundleId,
    this.bundleVersion,
    required this.environment,
  });

  /// Creates an [AppleNotificationData] from JSON data.
  factory AppleNotificationData.fromJson(Map<String, dynamic> json) =>
      _$AppleNotificationDataFromJson(json);

  /// The JWS signed transaction info.
  final String signedTransactionInfo;

  /// The JWS signed renewal info.
  final String signedRenewalInfo;

  /// The bundle identifier of the app.
  final String bundleId;

  /// The version of the app.
  final String? bundleVersion;

  /// The environment (Sandbox or Production).
  final AppleEnvironment environment;

  /// Converts this [AppleNotificationData] instance to JSON data.
  Map<String, dynamic> toJson() => _$AppleNotificationDataToJson(this);

  @override
  List<Object?> get props => [
        signedTransactionInfo,
        signedRenewalInfo,
        bundleId,
        bundleVersion,
        environment,
      ];
}

DateTime _dateTimeFromMilliseconds(int ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms);

int _dateTimeToMilliseconds(DateTime dt) => dt.millisecondsSinceEpoch;
