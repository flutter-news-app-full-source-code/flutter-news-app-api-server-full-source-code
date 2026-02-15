// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gcs_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GcsNotification _$GcsNotificationFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GcsNotification', json, ($checkedConvert) {
      final val = GcsNotification(
        message: $checkedConvert(
          'message',
          (v) => GcsMessage.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

GcsMessage _$GcsMessageFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GcsMessage', json, ($checkedConvert) {
      final val = GcsMessage(
        messageId: $checkedConvert('messageId', (v) => v as String),
        attributes: $checkedConvert(
          'attributes',
          (v) => GcsMessageAttributes.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

GcsMessageAttributes _$GcsMessageAttributesFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GcsMessageAttributes', json, ($checkedConvert) {
  final val = GcsMessageAttributes(
    eventType: $checkedConvert('eventType', (v) => v as String),
    objectId: $checkedConvert('objectId', (v) => v as String),
  );
  return val;
});
