import 'package:json_annotation/json_annotation.dart';

/// The type of notification sent by the Google Play server.
///
/// See: https://developer.android.com/google/play/billing/rtdn-reference#sub
enum GoogleNotificationType {
  /// A subscription was recovered from account hold.
  @JsonValue(1)
  subscriptionRecovered,

  /// An active subscription was renewed.
  @JsonValue(2)
  subscriptionRenewed,

  /// A subscription was canceled by the user.
  @JsonValue(3)
  subscriptionCanceled,

  /// A new subscription was purchased.
  @JsonValue(4)
  subscriptionPurchased,

  /// A subscription has entered account hold.
  @JsonValue(5)
  subscriptionOnHold,

  /// A subscription has entered grace period.
  @JsonValue(6)
  subscriptionInGracePeriod,

  /// User has reactivated their subscription from Play > Subscriptions.
  @JsonValue(7)
  subscriptionRestarted,

  /// A subscription price change has been confirmed by the user.
  @JsonValue(8)
  subscriptionPriceChangeConfirmed,

  /// A subscription's renewal time has been deferred.
  @JsonValue(9)
  subscriptionDeferred,

  /// A subscription has been paused.
  @JsonValue(10)
  subscriptionPaused,

  /// A subscription pause schedule has been changed.
  @JsonValue(11)
  subscriptionPauseScheduleChanged,

  /// A subscription has been revoked from the user.
  @JsonValue(12)
  subscriptionRevoked,

  /// A subscription has expired.
  @JsonValue(13)
  subscriptionExpired,
}
