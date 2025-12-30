// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sendgrid_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$SendGridRequestToJson(
  SendGridRequest instance,
) => <String, dynamic>{
  'stringify': instance.stringify,
  'hashCode': instance.hashCode,
  'personalizations': instance.personalizations.map((e) => e.toJson()).toList(),
  'from': instance.from.toJson(),
  'template_id': instance.templateId,
  'props': instance.props,
};

Map<String, dynamic> _$SendGridPersonalizationToJson(
  SendGridPersonalization instance,
) => <String, dynamic>{
  'stringify': instance.stringify,
  'hashCode': instance.hashCode,
  'to': instance.to.map((e) => e.toJson()).toList(),
  'subject': instance.subject,
  'dynamic_template_data': instance.dynamicTemplateData,
  'props': instance.props,
};

Map<String, dynamic> _$SendGridToToJson(SendGridTo instance) =>
    <String, dynamic>{
      'stringify': instance.stringify,
      'hashCode': instance.hashCode,
      'email': instance.email,
      'props': instance.props,
    };

Map<String, dynamic> _$SendGridFromToJson(SendGridFrom instance) =>
    <String, dynamic>{
      'stringify': instance.stringify,
      'hashCode': instance.hashCode,
      'email': instance.email,
      'props': instance.props,
    };
