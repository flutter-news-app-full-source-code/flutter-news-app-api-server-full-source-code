import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'google_subscription_purchase.g.dart';

/// {@template google_subscription_purchase}
/// Represents a subscription purchase resource from the Google Play API.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class GoogleSubscriptionPurchase extends Equatable {
  /// {@macro google_subscription_purchase}
  const GoogleSubscriptionPurchase({
    required this.expiryTimeMillis,
    required this.autoRenewing,
    this.paymentState,
  });

  /// Creates a [GoogleSubscriptionPurchase] from JSON data.
  factory GoogleSubscriptionPurchase.fromJson(Map<String, dynamic> json) =>
      _$GoogleSubscriptionPurchaseFromJson(json);

  /// Time at which the subscription will expire, in milliseconds since the
  /// Epoch.
  final String expiryTimeMillis;

  /// Whether the subscription will automatically renew at the end of the
  /// current term.
  final bool autoRenewing;

  /// The payment state of the subscription.
  /// 0. Payment pending
  /// 1. Payment received
  /// 2. Free trial
  /// 3. Pending deferred upgrade/downgrade
  final int? paymentState;

  /// Converts this instance to JSON data.
  Map<String, dynamic> toJson() => _$GoogleSubscriptionPurchaseToJson(this);

  @override
  List<Object?> get props => [expiryTimeMillis, autoRenewing, paymentState];
}
