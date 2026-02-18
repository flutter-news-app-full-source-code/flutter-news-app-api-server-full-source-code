// GENERATED CODE - DO NOT MODIFY BY HAND

part of 's3_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

S3Notification _$S3NotificationFromJson(Map<String, dynamic> json) =>
    $checkedCreate('S3Notification', json, ($checkedConvert) {
      final val = S3Notification(
        records: $checkedConvert(
          'Records',
          (v) => (v as List<dynamic>)
              .map((e) => S3Record.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    }, fieldKeyMap: const {'records': 'Records'});

S3Record _$S3RecordFromJson(Map<String, dynamic> json) =>
    $checkedCreate('S3Record', json, ($checkedConvert) {
      final val = S3Record(
        eventName: $checkedConvert('eventName', (v) => v as String),
        s3: $checkedConvert(
          's3',
          (v) => S3Entity.fromJson(v as Map<String, dynamic>),
        ),
        eventSource: $checkedConvert('eventSource', (v) => v as String?),
        awsRegion: $checkedConvert('awsRegion', (v) => v as String?),
        eventTime: $checkedConvert(
          'eventTime',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    });

S3Entity _$S3EntityFromJson(Map<String, dynamic> json) =>
    $checkedCreate('S3Entity', json, ($checkedConvert) {
      final val = S3Entity(
        object: $checkedConvert(
          'object',
          (v) => S3Object.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

S3Object _$S3ObjectFromJson(Map<String, dynamic> json) =>
    $checkedCreate('S3Object', json, ($checkedConvert) {
      final val = S3Object(key: $checkedConvert('key', (v) => v as String));
      return val;
    });
