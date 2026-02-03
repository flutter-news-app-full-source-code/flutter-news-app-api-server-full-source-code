// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_request_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$FirebaseRequestBodyToJson(
  FirebaseRequestBody instance,
) => <String, dynamic>{'message': instance.message.toJson()};

Map<String, dynamic> _$FirebaseMessageToJson(FirebaseMessage instance) =>
    <String, dynamic>{
      'token': instance.token,
      'notification': instance.notification.toJson(),
      'data': instance.data.toJson(),
    };

Map<String, dynamic> _$FirebaseNotificationToJson(
  FirebaseNotification instance,
) => <String, dynamic>{
  'title': instance.title,
  'body': instance.body,
  'image': instance.image,
};
