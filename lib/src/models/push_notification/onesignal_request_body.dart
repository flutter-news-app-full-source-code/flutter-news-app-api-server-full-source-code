import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'onesignal_request_body.g.dart';

/// {@template onesignal_request_body}
/// Represents the request body for the OneSignal /notifications endpoint.
/// {@endtemplate}
@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
  checked: true,
  fieldRename: FieldRename.snake,
  createFactory: false,
  ignoreUnannotated: true,
)
class OneSignalRequestBody extends Equatable {
  /// {@macro onesignal_request_body}
  const OneSignalRequestBody({
    required this.appId,
    required this.includePlayerIds,
    required this.headings,
    required this.data,
    this.contents,
    this.bigPicture,
  });

  /// The OneSignal App ID.
  @JsonKey()
  final String appId;

  /// A list of OneSignal Player IDs to send the notification to.
  @JsonKey()
  final List<String> includePlayerIds;

  /// The notification's title.
  @JsonKey()
  final Map<String, String> headings;

  /// The notification's content.
  @JsonKey()
  final Map<String, String>? contents;

  /// The custom data payload
  @JsonKey()
  final PushNotificationPayload data;

  /// The URL of a large image to display in the notification.
  @JsonKey()
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
