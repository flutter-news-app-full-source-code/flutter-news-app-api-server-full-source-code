import 'package:core/core.dart';

/// An abstract interface for push notification clients.
///
/// This interface defines the contract for sending push notifications
/// through different providers (e.g., Firebase Cloud Messaging, OneSignal).
abstract class IPushNotificationClient {
  /// Sends a push notification to a specific device.
  ///
  /// [deviceToken]: The unique token identifying the target device.
  /// [payload]: The data payload to be sent with the notification.
  Future<void> sendNotification({
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
  Future<void> sendBulkNotifications({
    required List<String> deviceTokens,
    required PushNotificationPayload payload,
  });
}
