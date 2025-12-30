import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'onesignal_request.g.dart';

/// {@template onesignal_email_request}
/// Represents the payload for sending an email via the OneSignal API.
/// {@endtemplate}
@JsonSerializable(
  explicitToJson: true,
  createFactory: false,
  ignoreUnannotated: true,
)
class OneSignalEmailRequest extends Equatable {
  /// {@macro onesignal_email_request}
  const OneSignalEmailRequest({
    required this.appId,
    required this.templateId,
    required this.includeEmailTokens,
    required this.emailSubject,
    required this.customData,
  });

  /// Converts a [OneSignalEmailRequest] to a JSON map.
  Map<String, dynamic> toJson() => _$OneSignalEmailRequestToJson(this);

  /// The OneSignal App ID.
  @JsonKey(name: 'app_id')
  final String appId;

  /// The ID of the template to use.
  @JsonKey(name: 'template_id')
  final String templateId;

  /// The list of email addresses (tokens) to target.
  @JsonKey(name: 'include_email_tokens')
  final List<String> includeEmailTokens;

  /// The subject line of the email.
  @JsonKey(name: 'email_subject')
  final String emailSubject;

  /// Custom data to be used for template substitution.
  @JsonKey(name: 'custom_data')
  final Map<String, dynamic> customData;

  @override
  List<Object?> get props => [
    appId,
    templateId,
    includeEmailTokens,
    emailSubject,
    customData,
  ];
}
