import 'package:equatable/equatable.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/enums.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'google_subscription_notification.g.dart';

/// {@template google_subscription_notification}
/// Represents the payload of a Google Play Real-Time Developer Notification.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class GoogleSubscriptionNotification extends Equatable {
  /// {@macro google_subscription_notification}
  const GoogleSubscriptionNotification({
    required this.version,
    required this.packageName,
    required this.eventTimeMillis,
    this.subscriptionNotification,
    this.testNotification,
  });

  /// Creates a [GoogleSubscriptionNotification] from JSON data.
  factory GoogleSubscriptionNotification.fromJson(Map<String, dynamic> json) =>
      _$GoogleSubscriptionNotificationFromJson(json);

  /// The version of the notification.
  final String version;

  /// The package name of the application.
  final String packageName;

  /// The timestamp of the event in milliseconds.
  final String eventTimeMillis;

  /// The subscription-specific notification details.
  final GoogleSubscriptionDetails? subscriptionNotification;

  /// Present if this is a test notification.
  final GoogleTestNotification? testNotification;

  /// Converts this [GoogleSubscriptionNotification] instance to JSON data.
  Map<String, dynamic> toJson() => _$GoogleSubscriptionNotificationToJson(this);

  @override
  List<Object?> get props => [
        version,
        packageName,
        eventTimeMillis,
        subscriptionNotification,
        testNotification,
      ];
}

/// {@template google_subscription_details}
/// Details about a subscription event.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class GoogleSubscriptionDetails extends Equatable {
  /// {@macro google_subscription_details}
  const GoogleSubscriptionDetails({
    required this.version,
    required this.notificationType,
    required this.purchaseToken,
    required this.subscriptionId,
  });

  /// Creates a [GoogleSubscriptionDetails] from JSON data.
  factory GoogleSubscriptionDetails.fromJson(Map<String, dynamic> json) =>
      _$GoogleSubscriptionDetailsFromJson(json);

  /// The version of the notification.
  final String version;

  /// The type of notification.
  final GoogleNotificationType notificationType;

  /// The token provided to the user's device when the subscription was purchased.
  final String purchaseToken;

  /// The product ID of the subscription.
  final String subscriptionId;

  /// Converts this [GoogleSubscriptionDetails] instance to JSON data.
  Map<String, dynamic> toJson() => _$GoogleSubscriptionDetailsToJson(this);

  @override
  List<Object?> get props => [
        version,
        notificationType,
        purchaseToken,
        subscriptionId,
      ];
}

/// {@template google_test_notification}
/// Details for a test notification.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class GoogleTestNotification extends Equatable {
  /// {@macro google_test_notification}
  const GoogleTestNotification({required this.version});

  /// Creates a [GoogleTestNotification] from JSON data.
  factory GoogleTestNotification.fromJson(Map<String, dynamic> json) =>
      _$GoogleTestNotificationFromJson(json);

  /// The version of the test notification.
  final String version;

  /// Converts this [GoogleTestNotification] instance to JSON data.
  Map<String, dynamic> toJson() => _$GoogleTestNotificationToJson(this);

  @override
  List<Object?> get props => [version];
}
