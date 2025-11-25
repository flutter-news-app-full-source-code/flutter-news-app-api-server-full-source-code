// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_request_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FirebaseRequestBody _$FirebaseRequestBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FirebaseRequestBody', json, ($checkedConvert) {
      final val = FirebaseRequestBody(
        message: $checkedConvert(
          'message',
          (v) => FirebaseMessage.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$FirebaseRequestBodyToJson(
  FirebaseRequestBody instance,
) => <String, dynamic>{'message': instance.message.toJson()};

FirebaseMessage _$FirebaseMessageFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FirebaseMessage', json, ($checkedConvert) {
      final val = FirebaseMessage(
        token: $checkedConvert('token', (v) => v as String),
        notification: $checkedConvert(
          'notification',
          (v) => FirebaseNotification.fromJson(v as Map<String, dynamic>),
        ),
        data: $checkedConvert(
          'data',
          (v) => PushNotificationPayload.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$FirebaseMessageToJson(FirebaseMessage instance) =>
    <String, dynamic>{
      'token': instance.token,
      'notification': instance.notification.toJson(),
      'data': instance.data.toJson(),
    };

FirebaseNotification _$FirebaseNotificationFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('FirebaseNotification', json, ($checkedConvert) {
  final val = FirebaseNotification(
    title: $checkedConvert('title', (v) => v as String),
    body: $checkedConvert('body', (v) => v as String),
    image: $checkedConvert('image', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$FirebaseNotificationToJson(
  FirebaseNotification instance,
) => <String, dynamic>{
  'title': instance.title,
  'body': instance.body,
  'image': instance.image,
};
