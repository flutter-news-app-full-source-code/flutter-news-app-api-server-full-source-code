import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// {@template push_notification_result}
/// Encapsulates the result of a bulk push notification send operation.
///
/// This class provides structured feedback on which notifications were sent
/// successfully and which ones failed, including the specific device tokens
/// for each category. This is crucial for implementing self-healing mechanisms,
/// such as cleaning up invalid or unregistered device tokens from the database.
/// {@endtemplate}
@immutable
class PushNotificationResult extends Equatable {
  /// {@macro push_notification_result}
  const PushNotificationResult({
    this.sentTokens = const [],
    this.failedTokens = const [],
  });

  /// A list of device tokens to which the notification was successfully sent.
  final List<String> sentTokens;

  /// A list of device tokens to which the notification failed to be sent.
  final List<String> failedTokens;

  @override
  List<Object> get props => [sentTokens, failedTokens];
}

/// An abstract interface for push notification clients.
///
/// This interface defines the contract for sending push notifications
/// through different providers (e.g., Firebase Cloud Messaging, OneSignal).
abstract class IPushNotificationClient {
  /// Sends a push notification to a specific device.
  ///
  /// [deviceToken]: The unique token identifying the target device.
  /// [payload]: The data payload to be sent with the notification.
  Future<PushNotificationResult> sendNotification({
    required String deviceToken,
    required PushNotificationPayload payload,
  });

  /// Sends a push notification to a batch of devices.
  ///
  /// This method is more efficient for sending the same notification to
  /// multiple recipients, as it can reduce the number of API calls.
  ///
  /// [deviceTokens]: A list of unique tokens identifying the target devices.
  /// [payload]: The data payload to be sent with the notification.
  Future<PushNotificationResult> sendBulkNotifications({
    required List<String> deviceTokens,
    required PushNotificationPayload payload,
  });
}
