import 'package:json_annotation/json_annotation.dart';

/// The type of notification sent by the App Store server.
@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum AppleNotificationType {
  /// A notification type that indicates that the customer consented to a price
  /// increase.
  consent,

  /// A notification type that indicates that the subscription-renewal-date has
  /// changed.
  didChangeRenewalPref,

  /// A notification type that indicates that the subscription-renewal status
  /// has changed.
  didChangeRenewalStatus,

  /// A notification type that indicates that the subscription failed to renew
  /// due to a billing issue.
  didFailToRenew,

  /// A notification type that indicates that the subscription successfully
  /// renewed.
  didRenew,

  /// A notification type that indicates that a subscription has expired.
  expired,

  /// A notification type that indicates that the billing grace period has
  /// expired without a successful renewal.
  gracePeriodExpired,

  /// A notification type that indicates that the App Store is attempting to
  /// charge the user’s account for a subscription that they’ve purchased.
  offerRedeemed,

  /// A notification type that indicates that the App Store has started asking
  /// the user for consent to a price increase.
  priceIncrease,

  /// A notification type that indicates that the App Store has issued a refund
  /// for a transaction.
  refund,

  /// A notification type that indicates that the App Store has revoked a
  /// transaction.
  revoke,

  /// A notification type that indicates that a user has subscribed to a
  /// product.
  subscribed,

  /// A notification type that indicates that the App Store has temporarily
  /// suspended a subscription renewal.
  renewalExtended,

  /// A notification type that indicates that the App Store has extended the
  /// subscription renewal date for a specific subscription.
  renewalExtension,

  /// A notification type that indicates that the App Store has reversed a
  /// transaction refund.
  refundReversed,

  /// A notification type that indicates that the consumption data that you
  /// provided for a consumable in-app purchase was invalid.
  consumptionRequest,
}
