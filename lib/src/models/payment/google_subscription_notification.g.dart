// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_subscription_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleSubscriptionNotification _$GoogleSubscriptionNotificationFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GoogleSubscriptionNotification', json, ($checkedConvert) {
  final val = GoogleSubscriptionNotification(
    version: $checkedConvert('version', (v) => v as String),
    packageName: $checkedConvert('packageName', (v) => v as String),
    eventTimeMillis: $checkedConvert('eventTimeMillis', (v) => v as String),
    subscriptionNotification: $checkedConvert(
      'subscriptionNotification',
      (v) => v == null
          ? null
          : GoogleSubscriptionDetails.fromJson(v as Map<String, dynamic>),
    ),
    testNotification: $checkedConvert(
      'testNotification',
      (v) => v == null
          ? null
          : GoogleTestNotification.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$GoogleSubscriptionNotificationToJson(
  GoogleSubscriptionNotification instance,
) => <String, dynamic>{
  'version': instance.version,
  'packageName': instance.packageName,
  'eventTimeMillis': instance.eventTimeMillis,
  'subscriptionNotification': instance.subscriptionNotification?.toJson(),
  'testNotification': instance.testNotification?.toJson(),
};

GoogleSubscriptionDetails _$GoogleSubscriptionDetailsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GoogleSubscriptionDetails', json, ($checkedConvert) {
  final val = GoogleSubscriptionDetails(
    version: $checkedConvert('version', (v) => v as String),
    notificationType: $checkedConvert(
      'notificationType',
      (v) => $enumDecode(_$GoogleNotificationTypeEnumMap, v),
    ),
    purchaseToken: $checkedConvert('purchaseToken', (v) => v as String),
    subscriptionId: $checkedConvert('subscriptionId', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$GoogleSubscriptionDetailsToJson(
  GoogleSubscriptionDetails instance,
) => <String, dynamic>{
  'version': instance.version,
  'notificationType':
      _$GoogleNotificationTypeEnumMap[instance.notificationType]!,
  'purchaseToken': instance.purchaseToken,
  'subscriptionId': instance.subscriptionId,
};

const _$GoogleNotificationTypeEnumMap = {
  GoogleNotificationType.subscriptionRecovered: 1,
  GoogleNotificationType.subscriptionRenewed: 2,
  GoogleNotificationType.subscriptionCanceled: 3,
  GoogleNotificationType.subscriptionPurchased: 4,
  GoogleNotificationType.subscriptionOnHold: 5,
  GoogleNotificationType.subscriptionInGracePeriod: 6,
  GoogleNotificationType.subscriptionRestarted: 7,
  GoogleNotificationType.subscriptionPriceChangeConfirmed: 8,
  GoogleNotificationType.subscriptionDeferred: 9,
  GoogleNotificationType.subscriptionPaused: 10,
  GoogleNotificationType.subscriptionPauseScheduleChanged: 11,
  GoogleNotificationType.subscriptionRevoked: 12,
  GoogleNotificationType.subscriptionExpired: 13,
};

GoogleTestNotification _$GoogleTestNotificationFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GoogleTestNotification', json, ($checkedConvert) {
  final val = GoogleTestNotification(
    version: $checkedConvert('version', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$GoogleTestNotificationToJson(
  GoogleTestNotification instance,
) => <String, dynamic>{'version': instance.version};
