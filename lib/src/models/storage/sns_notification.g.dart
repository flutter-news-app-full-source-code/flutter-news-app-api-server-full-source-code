// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sns_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SnsNotification _$SnsNotificationFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'SnsNotification',
      json,
      ($checkedConvert) {
        final val = SnsNotification(
          type: $checkedConvert('Type', (v) => v as String),
          messageId: $checkedConvert('MessageId', (v) => v as String?),
          topicArn: $checkedConvert('TopicArn', (v) => v as String?),
          message: $checkedConvert('Message', (v) => v as String?),
          timestamp: $checkedConvert(
            'Timestamp',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          subscribeUrl: $checkedConvert('SubscribeURL', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {
        'type': 'Type',
        'messageId': 'MessageId',
        'topicArn': 'TopicArn',
        'message': 'Message',
        'timestamp': 'Timestamp',
        'subscribeUrl': 'SubscribeURL',
      },
    );
