// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'idempotency_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IdempotencyRecord _$IdempotencyRecordFromJson(Map<String, dynamic> json) =>
    $checkedCreate('IdempotencyRecord', json, ($checkedConvert) {
      final val = IdempotencyRecord(
        id: $checkedConvert('id', (v) => v as String),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$IdempotencyRecordToJson(IdempotencyRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
    };
