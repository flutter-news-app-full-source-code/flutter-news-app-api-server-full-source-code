// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apple_notification_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppleNotificationPayload _$AppleNotificationPayloadFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AppleNotificationPayload', json, ($checkedConvert) {
  final val = AppleNotificationPayload(
    notificationType: $checkedConvert(
      'notificationType',
      (v) => $enumDecode(_$AppleNotificationTypeEnumMap, v),
    ),
    notificationUUID: $checkedConvert('notificationUUID', (v) => v as String),
    data: $checkedConvert(
      'data',
      (v) => AppleNotificationData.fromJson(v as Map<String, dynamic>),
    ),
    version: $checkedConvert('version', (v) => v as String),
    signedDate: $checkedConvert(
      'signedDate',
      (v) => _dateTimeFromMilliseconds((v as num).toInt()),
    ),
    subtype: $checkedConvert(
      'subtype',
      (v) => $enumDecodeNullable(_$AppleNotificationSubtypeEnumMap, v),
    ),
  );
  return val;
});

Map<String, dynamic> _$AppleNotificationPayloadToJson(
  AppleNotificationPayload instance,
) => <String, dynamic>{
  'notificationType':
      _$AppleNotificationTypeEnumMap[instance.notificationType]!,
  'subtype': _$AppleNotificationSubtypeEnumMap[instance.subtype],
  'notificationUUID': instance.notificationUUID,
  'data': instance.data.toJson(),
  'version': instance.version,
  'signedDate': _dateTimeToMilliseconds(instance.signedDate),
};

const _$AppleNotificationTypeEnumMap = {
  AppleNotificationType.consent: 'CONSENT',
  AppleNotificationType.didChangeRenewalPref: 'DID_CHANGE_RENEWAL_PREF',
  AppleNotificationType.didChangeRenewalStatus: 'DID_CHANGE_RENEWAL_STATUS',
  AppleNotificationType.didFailToRenew: 'DID_FAIL_TO_RENEW',
  AppleNotificationType.didRenew: 'DID_RENEW',
  AppleNotificationType.expired: 'EXPIRED',
  AppleNotificationType.gracePeriodExpired: 'GRACE_PERIOD_EXPIRED',
  AppleNotificationType.offerRedeemed: 'OFFER_REDEEMED',
  AppleNotificationType.priceIncrease: 'PRICE_INCREASE',
  AppleNotificationType.refund: 'REFUND',
  AppleNotificationType.revoke: 'REVOKE',
  AppleNotificationType.subscribed: 'SUBSCRIBED',
  AppleNotificationType.renewalExtended: 'RENEWAL_EXTENDED',
  AppleNotificationType.renewalExtension: 'RENEWAL_EXTENSION',
  AppleNotificationType.refundReversed: 'REFUND_REVERSED',
  AppleNotificationType.consumptionRequest: 'CONSUMPTION_REQUEST',
};

const _$AppleNotificationSubtypeEnumMap = {
  AppleNotificationSubtype.initialBuy: 'INITIAL_BUY',
  AppleNotificationSubtype.resubscribe: 'RESUBSCRIBE',
  AppleNotificationSubtype.downgrade: 'DOWNGRADE',
  AppleNotificationSubtype.upgrade: 'UPGRADE',
  AppleNotificationSubtype.crossgrade: 'CROSSGRADE',
  AppleNotificationSubtype.transfer: 'TRANSFER',
  AppleNotificationSubtype.autoRenewEnabled: 'AUTO_RENEW_ENABLED',
  AppleNotificationSubtype.autoRenewDisabled: 'AUTO_RENEW_DISABLED',
  AppleNotificationSubtype.voluntary: 'VOLUNTARY',
  AppleNotificationSubtype.billingRetry: 'BILLING_RETRY',
  AppleNotificationSubtype.priceIncrease: 'PRICE_INCREASE',
  AppleNotificationSubtype.gracePeriod: 'GRACE_PERIOD',
  AppleNotificationSubtype.billingRecovery: 'BILLING_RECOVERY',
  AppleNotificationSubtype.pending: 'PENDING',
  AppleNotificationSubtype.accepted: 'ACCEPTED',
};

AppleNotificationData _$AppleNotificationDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AppleNotificationData', json, ($checkedConvert) {
  final val = AppleNotificationData(
    signedTransactionInfo: $checkedConvert(
      'signedTransactionInfo',
      (v) => v as String,
    ),
    signedRenewalInfo: $checkedConvert('signedRenewalInfo', (v) => v as String),
    bundleId: $checkedConvert('bundleId', (v) => v as String),
    environment: $checkedConvert(
      'environment',
      (v) => $enumDecode(_$AppleEnvironmentEnumMap, v),
    ),
    bundleVersion: $checkedConvert('bundleVersion', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$AppleNotificationDataToJson(
  AppleNotificationData instance,
) => <String, dynamic>{
  'signedTransactionInfo': instance.signedTransactionInfo,
  'signedRenewalInfo': instance.signedRenewalInfo,
  'bundleId': instance.bundleId,
  'bundleVersion': instance.bundleVersion,
  'environment': _$AppleEnvironmentEnumMap[instance.environment]!,
};

const _$AppleEnvironmentEnumMap = {
  AppleEnvironment.sandbox: 'Sandbox',
  AppleEnvironment.production: 'Production',
};
