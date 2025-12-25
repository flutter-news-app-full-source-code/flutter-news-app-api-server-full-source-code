import 'package:equatable/equatable.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/payment/apple_environment.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'apple_subscription_response.g.dart';

/// {@template apple_subscription_response}
/// Represents the response from Apple's 'Get All Subscription Statuses' endpoint.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class AppleSubscriptionResponse extends Equatable {
  /// {@macro apple_subscription_response}
  const AppleSubscriptionResponse({
    required this.environment,
    required this.bundleId,
    required this.data,
  });

  /// Creates an [AppleSubscriptionResponse] from JSON data.
  factory AppleSubscriptionResponse.fromJson(Map<String, dynamic> json) =>
      _$AppleSubscriptionResponseFromJson(json);

  /// The environment for the subscription.
  final AppleEnvironment environment;

  /// The bundle identifier of the app.
  final String bundleId;

  /// An array of subscription-group-identifier-item objects.
  final List<AppleSubscriptionGroupItem> data;

  /// Converts this instance to JSON data.
  Map<String, dynamic> toJson() => _$AppleSubscriptionResponseToJson(this);

  @override
  List<Object?> get props => [environment, bundleId, data];
}

/// {@template apple_subscription_group_item}
/// Contains the subscription information for a subscription group.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class AppleSubscriptionGroupItem extends Equatable {
  /// {@macro apple_subscription_group_item}
  const AppleSubscriptionGroupItem({
    required this.subscriptionGroupIdentifier,
    required this.lastTransactions,
  });

  /// Creates an [AppleSubscriptionGroupItem] from JSON data.
  factory AppleSubscriptionGroupItem.fromJson(Map<String, dynamic> json) =>
      _$AppleSubscriptionGroupItemFromJson(json);

  /// The subscription group identifier.
  final String subscriptionGroupIdentifier;

  /// An array of the most recent signed transaction information and signed
  /// renewal information for all subscriptions in the subscription group.
  final List<AppleLastTransactionItem> lastTransactions;

  /// Converts this instance to JSON data.
  Map<String, dynamic> toJson() => _$AppleSubscriptionGroupItemToJson(this);

  @override
  List<Object?> get props => [subscriptionGroupIdentifier, lastTransactions];
}

/// {@template apple_last_transaction_item}
/// The most recent signed transaction information and signed renewal
/// information for a subscription.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class AppleLastTransactionItem extends Equatable {
  /// {@macro apple_last_transaction_item}
  const AppleLastTransactionItem({
    required this.originalTransactionId,
    required this.status,
    required this.signedRenewalInfo,
    required this.signedTransactionInfo,
  });

  /// Creates an [AppleLastTransactionItem] from JSON data.
  factory AppleLastTransactionItem.fromJson(Map<String, dynamic> json) =>
      _$AppleLastTransactionItemFromJson(json);

  /// The original transaction identifier of a purchase.
  final String originalTransactionId;

  /// The subscription status.
  /// 1 - Active, 2 - Expired, 3 - In Billing Retry, 4 - In Grace Period, 5 - Revoked
  final int status;

  /// The renewal information for the most recent transaction, signed by Apple.
  final String signedRenewalInfo;

  /// The transaction information for the most recent transaction, signed by Apple.
  final String signedTransactionInfo;

  /// Converts this instance to JSON data.
  Map<String, dynamic> toJson() => _$AppleLastTransactionItemToJson(this);

  @override
  List<Object?> get props => [
        originalTransactionId,
        status,
        signedRenewalInfo,
        signedTransactionInfo,
      ];
}
