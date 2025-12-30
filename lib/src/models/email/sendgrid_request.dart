import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sendgrid_request.g.dart';

/// {@template sendgrid_request}
/// Represents the payload for sending an email via the SendGrid v3 API.
/// {@endtemplate}
@JsonSerializable(explicitToJson: true, createFactory: false)
class SendGridRequest extends Equatable {
  /// {@macro sendgrid_request}
  const SendGridRequest({
    required this.personalizations,
    required this.from,
    required this.templateId,
  });

  /// Converts a [SendGridRequest] to a JSON map.
  Map<String, dynamic> toJson() => _$SendGridRequestToJson(this);

  /// The list of personalizations (recipients and dynamic data).
  final List<SendGridPersonalization> personalizations;

  /// The sender's email information.
  final SendGridFrom from;

  /// The ID of the dynamic template to use.
  @JsonKey(name: 'template_id')
  final String templateId;

  @override
  List<Object?> get props => [personalizations, from, templateId];
}

/// {@template sendgrid_personalization}
/// Represents the personalization block within a SendGrid request.
/// {@endtemplate}
@JsonSerializable(explicitToJson: true, createFactory: false)
class SendGridPersonalization extends Equatable {
  /// {@macro sendgrid_personalization}
  const SendGridPersonalization({
    required this.to,
    required this.subject,
    required this.dynamicTemplateData,
  });

  /// Converts a [SendGridPersonalization] to a JSON map.
  Map<String, dynamic> toJson() => _$SendGridPersonalizationToJson(this);

  /// The recipients of this personalization.
  final List<SendGridTo> to;

  /// The subject line for this personalization.
  final String subject;

  /// The dynamic data to inject into the template.
  @JsonKey(name: 'dynamic_template_data')
  final Map<String, dynamic> dynamicTemplateData;

  @override
  List<Object?> get props => [to, subject, dynamicTemplateData];
}

/// {@template sendgrid_to}
/// Represents a recipient in a SendGrid request.
/// {@endtemplate}
@JsonSerializable(createFactory: false)
class SendGridTo extends Equatable {
  /// {@macro sendgrid_to}
  const SendGridTo({required this.email});

  /// Converts a [SendGridTo] to a JSON map.
  Map<String, dynamic> toJson() => _$SendGridToToJson(this);

  /// The recipient's email address.
  final String email;

  @override
  List<Object?> get props => [email];
}

/// {@template sendgrid_from}
/// Represents the sender in a SendGrid request.
/// {@endtemplate}
@JsonSerializable(createFactory: false)
class SendGridFrom extends Equatable {
  /// {@macro sendgrid_from}
  const SendGridFrom({required this.email});

  /// Converts a [SendGridFrom] to a JSON map.
  Map<String, dynamic> toJson() => _$SendGridFromToJson(this);

  /// The sender's email address.
  final String email;

  @override
  List<Object?> get props => [email];
}
