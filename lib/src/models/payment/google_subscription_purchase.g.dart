// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_subscription_purchase.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleSubscriptionPurchase _$GoogleSubscriptionPurchaseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GoogleSubscriptionPurchase', json, ($checkedConvert) {
  final val = GoogleSubscriptionPurchase(
    expiryTimeMillis: $checkedConvert('expiryTimeMillis', (v) => v as String),
    autoRenewing: $checkedConvert('autoRenewing', (v) => v as bool),
    paymentState: $checkedConvert('paymentState', (v) => (v as num?)?.toInt()),
  );
  return val;
});

Map<String, dynamic> _$GoogleSubscriptionPurchaseToJson(
  GoogleSubscriptionPurchase instance,
) => <String, dynamic>{
  'expiryTimeMillis': instance.expiryTimeMillis,
  'autoRenewing': instance.autoRenewing,
  'paymentState': instance.paymentState,
};
