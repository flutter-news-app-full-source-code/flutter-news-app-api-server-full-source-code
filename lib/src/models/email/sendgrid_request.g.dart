// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sendgrid_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SendGridRequest _$SendGridRequestFromJson(Map<String, dynamic> json) =>
    SendGridRequest(
      personalizations: (json['personalizations'] as List<dynamic>)
          .map(
            (e) => SendGridPersonalization.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      from: SendGridFrom.fromJson(json['from'] as Map<String, dynamic>),
      templateId: json['template_id'] as String,
    );

Map<String, dynamic> _$SendGridRequestToJson(
  SendGridRequest instance,
) => <String, dynamic>{
  'personalizations': instance.personalizations.map((e) => e.toJson()).toList(),
  'from': instance.from.toJson(),
  'template_id': instance.templateId,
};

SendGridPersonalization _$SendGridPersonalizationFromJson(
  Map<String, dynamic> json,
) => SendGridPersonalization(
  to: (json['to'] as List<dynamic>)
      .map((e) => SendGridTo.fromJson(e as Map<String, dynamic>))
      .toList(),
  subject: json['subject'] as String,
  dynamicTemplateData: json['dynamic_template_data'] as Map<String, dynamic>,
);

Map<String, dynamic> _$SendGridPersonalizationToJson(
  SendGridPersonalization instance,
) => <String, dynamic>{
  'to': instance.to.map((e) => e.toJson()).toList(),
  'subject': instance.subject,
  'dynamic_template_data': instance.dynamicTemplateData,
};

SendGridTo _$SendGridToFromJson(Map<String, dynamic> json) =>
    SendGridTo(email: json['email'] as String);

Map<String, dynamic> _$SendGridToToJson(SendGridTo instance) =>
    <String, dynamic>{'email': instance.email};

SendGridFrom _$SendGridFromFromJson(Map<String, dynamic> json) =>
    SendGridFrom(email: json['email'] as String);

Map<String, dynamic> _$SendGridFromToJson(SendGridFrom instance) =>
    <String, dynamic>{'email': instance.email};
