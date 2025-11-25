// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onesignal_request_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OneSignalRequestBody _$OneSignalRequestBodyFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'OneSignalRequestBody',
  json,
  ($checkedConvert) {
    final val = OneSignalRequestBody(
      appId: $checkedConvert('app_id', (v) => v as String),
      includePlayerIds: $checkedConvert(
        'include_player_ids',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      headings: $checkedConvert(
        'headings',
        (v) => Map<String, String>.from(v as Map),
      ),
      contents: $checkedConvert(
        'contents',
        (v) => Map<String, String>.from(v as Map),
      ),
      data: $checkedConvert(
        'data',
        (v) => PushNotificationPayload.fromJson(v as Map<String, dynamic>),
      ),
      bigPicture: $checkedConvert('big_picture', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'appId': 'app_id',
    'includePlayerIds': 'include_player_ids',
    'bigPicture': 'big_picture',
  },
);

Map<String, dynamic> _$OneSignalRequestBodyToJson(
  OneSignalRequestBody instance,
) => <String, dynamic>{
  'app_id': instance.appId,
  'include_player_ids': instance.includePlayerIds,
  'headings': instance.headings,
  'contents': instance.contents,
  'data': instance.data.toJson(),
  'big_picture': ?instance.bigPicture,
};
