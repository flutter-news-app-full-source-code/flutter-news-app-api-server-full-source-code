import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'onesignal_request_body.g.dart';

/// {@template onesignal_request_body}
/// Represents the request body for the OneSignal /notifications endpoint.
/// {@endtemplate}
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false, // Do not include null fields in the JSON
  checked: true,
  fieldRename: FieldRename.snake,
)
class OneSignalRequestBody extends Equatable {
  /// {@macro onesignal_request_body}
  const OneSignalRequestBody({
    required this.appId,
    required this.includePlayerIds,
    required this.headings,
    required this.contents,
    required this.data,
    this.bigPicture,
  });

  /// The OneSignal App ID.
  final String appId;

  /// A list of OneSignal Player IDs to send the notification to.
  final List<String> includePlayerIds;

  /// The notification's title.
  final Map<String, String> headings;

  /// The notification's content.
  final Map<String, String> contents;

  /// The custom data payload
  final PushNotificationPayload data;

  /// The URL of a large image to display in the notification.
  final String? bigPicture;

  /// Converts this [OneSignalRequestBody] instance to a JSON map.
  Map<String, dynamic> toJson() => _$OneSignalRequestBodyToJson(this);

  @override
  List<Object?> get props => [
    appId,
    includePlayerIds,
    headings,
    contents,
    data,
    bigPicture,
  ];
}
