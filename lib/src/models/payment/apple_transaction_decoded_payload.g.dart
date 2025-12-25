// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apple_transaction_decoded_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppleTransactionDecodedPayload _$AppleTransactionDecodedPayloadFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AppleTransactionDecodedPayload', json, ($checkedConvert) {
  final val = AppleTransactionDecodedPayload(
    originalTransactionId: $checkedConvert(
      'originalTransactionId',
      (v) => v as String,
    ),
    transactionId: $checkedConvert('transactionId', (v) => v as String),
    productId: $checkedConvert('productId', (v) => v as String),
    purchaseDate: $checkedConvert(
      'purchaseDate',
      (v) => _dateTimeFromMilliseconds((v as num).toInt()),
    ),
    originalPurchaseDate: $checkedConvert(
      'originalPurchaseDate',
      (v) => _dateTimeFromMilliseconds((v as num).toInt()),
    ),
    expiresDate: $checkedConvert(
      'expiresDate',
      (v) => _dateTimeFromMilliseconds((v as num).toInt()),
    ),
    type: $checkedConvert('type', (v) => v as String),
    inAppOwnershipType: $checkedConvert(
      'inAppOwnershipType',
      (v) => v as String,
    ),
  );
  return val;
});

Map<String, dynamic> _$AppleTransactionDecodedPayloadToJson(
  AppleTransactionDecodedPayload instance,
) => <String, dynamic>{
  'originalTransactionId': instance.originalTransactionId,
  'transactionId': instance.transactionId,
  'productId': instance.productId,
  'purchaseDate': _dateTimeToMilliseconds(instance.purchaseDate),
  'originalPurchaseDate': _dateTimeToMilliseconds(
    instance.originalPurchaseDate,
  ),
  'expiresDate': _dateTimeToMilliseconds(instance.expiresDate),
  'type': instance.type,
  'inAppOwnershipType': instance.inAppOwnershipType,
};
