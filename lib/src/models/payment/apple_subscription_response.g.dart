// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apple_subscription_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppleSubscriptionResponse _$AppleSubscriptionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AppleSubscriptionResponse', json, ($checkedConvert) {
  final val = AppleSubscriptionResponse(
    environment: $checkedConvert(
      'environment',
      (v) => $enumDecode(_$AppleEnvironmentEnumMap, v),
    ),
    bundleId: $checkedConvert('bundleId', (v) => v as String),
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map(
            (e) =>
                AppleSubscriptionGroupItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$AppleSubscriptionResponseToJson(
  AppleSubscriptionResponse instance,
) => <String, dynamic>{
  'environment': _$AppleEnvironmentEnumMap[instance.environment]!,
  'bundleId': instance.bundleId,
  'data': instance.data.map((e) => e.toJson()).toList(),
};

const _$AppleEnvironmentEnumMap = {
  AppleEnvironment.sandbox: 'Sandbox',
  AppleEnvironment.production: 'Production',
};

AppleSubscriptionGroupItem _$AppleSubscriptionGroupItemFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AppleSubscriptionGroupItem', json, ($checkedConvert) {
  final val = AppleSubscriptionGroupItem(
    subscriptionGroupIdentifier: $checkedConvert(
      'subscriptionGroupIdentifier',
      (v) => v as String,
    ),
    lastTransactions: $checkedConvert(
      'lastTransactions',
      (v) => (v as List<dynamic>)
          .map(
            (e) => AppleLastTransactionItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$AppleSubscriptionGroupItemToJson(
  AppleSubscriptionGroupItem instance,
) => <String, dynamic>{
  'subscriptionGroupIdentifier': instance.subscriptionGroupIdentifier,
  'lastTransactions': instance.lastTransactions.map((e) => e.toJson()).toList(),
};

AppleLastTransactionItem _$AppleLastTransactionItemFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AppleLastTransactionItem', json, ($checkedConvert) {
  final val = AppleLastTransactionItem(
    originalTransactionId: $checkedConvert(
      'originalTransactionId',
      (v) => v as String,
    ),
    status: $checkedConvert('status', (v) => (v as num).toInt()),
    signedRenewalInfo: $checkedConvert('signedRenewalInfo', (v) => v as String),
    signedTransactionInfo: $checkedConvert(
      'signedTransactionInfo',
      (v) => v as String,
    ),
  );
  return val;
});

Map<String, dynamic> _$AppleLastTransactionItemToJson(
  AppleLastTransactionItem instance,
) => <String, dynamic>{
  'originalTransactionId': instance.originalTransactionId,
  'status': instance.status,
  'signedRenewalInfo': instance.signedRenewalInfo,
  'signedTransactionInfo': instance.signedTransactionInfo,
};
