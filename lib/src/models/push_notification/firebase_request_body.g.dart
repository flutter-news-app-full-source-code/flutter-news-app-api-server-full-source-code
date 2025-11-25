// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_request_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$FirebaseRequestBodyToJson(
  FirebaseRequestBody instance,
) => <String, dynamic>{
  'stringify': instance.stringify,
  'hashCode': instance.hashCode,
  'message': instance.message.toJson(),
  'props': instance.props,
};

Map<String, dynamic> _$FirebaseMessageToJson(FirebaseMessage instance) =>
    <String, dynamic>{
      'stringify': instance.stringify,
      'hashCode': instance.hashCode,
      'token': instance.token,
      'notification': instance.notification.toJson(),
      'data': instance.data.toJson(),
      'props': instance.props,
    };

Map<String, dynamic> _$FirebaseNotificationToJson(
  FirebaseNotification instance,
) => <String, dynamic>{
  'stringify': instance.stringify,
  'hashCode': instance.hashCode,
  'title': instance.title,
  'body': instance.body,
  'image': instance.image,
  'props': instance.props,
};
