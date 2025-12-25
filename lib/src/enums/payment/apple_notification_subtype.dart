import 'package:json_annotation/json_annotation.dart';

/// The subtype for the notification.
@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum AppleNotificationSubtype {
  /// A notification with this subtype indicates that the user purchased the
  /// subscription for the first time.
  initialBuy,

  /// A notification with this subtype indicates that the user resubscribed to
  /// the same subscription or to a subscription within the same subscription
  /// group.
  resubscribe,

  /// A notification with this subtype indicates that the user downgraded their
  /// subscription.
  downgrade,

  /// A notification with this subtype indicates that the user upgraded their
  /// subscription.
  upgrade,

  /// A notification with this subtype indicates that the user made a
  /// cross-grade to a subscription of the same level.
  crossgrade,

  /// A notification with this subtype indicates that the subscription transfer
  /// to another user was successful.
  transfer,

  /// A notification with this subtype indicates that the subscription auto-
  /// renewal is enabled.
  autoRenewEnabled,

  /// A notification with this subtype indicates that the subscription auto-
  /// renewal is disabled.
  autoRenewDisabled,

  /// A notification with this subtype indicates that the subscription is in a
  /// voluntary grace period.
  voluntary,

  /// A notification with this subtype indicates that the subscription is in a
  /// billing grace period.
  billingRetry,

  /// A notification with this subtype indicates that the subscription price
  /// increase is pending user consent.
  priceIncrease,

  /// A notification with this subtype indicates that the subscription grace
  /// period has expired.
  gracePeriod,

  /// A notification with this subtype indicates that the subscription has been
  /// transferred to another user.
  billingRecovery,

  /// A notification with this subtype indicates that the subscription is
  /// pending a price increase consent.
  pending,

  /// A notification with this subtype indicates that the subscription has been
  /// accepted.
  accepted,
}
