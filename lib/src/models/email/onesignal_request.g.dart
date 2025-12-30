// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onesignal_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OneSignalEmailRequest _$OneSignalEmailRequestFromJson(
  Map<String, dynamic> json,
) => OneSignalEmailRequest(
  appId: json['app_id'] as String,
  templateId: json['template_id'] as String,
  includeEmailTokens: (json['include_email_tokens'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  emailSubject: json['email_subject'] as String,
  customData: json['custom_data'] as Map<String, dynamic>,
);

Map<String, dynamic> _$OneSignalEmailRequestToJson(
  OneSignalEmailRequest instance,
) => <String, dynamic>{
  'app_id': instance.appId,
  'template_id': instance.templateId,
  'include_email_tokens': instance.includeEmailTokens,
  'email_subject': instance.emailSubject,
  'custom_data': instance.customData,
};
