import 'package:core/core.dart';

/// An abstract interface for push notification clients.///
/// This interface defines the contract for sending push notifications
/// through different providers (e.g., Firebase Cloud Messaging, OneSignal).
abstract class IPushNotificationClient {
  /// Sends a push notification to a specific device.
  ///
  /// [deviceToken]: The unique token identifying the target device.
  /// [payload]: The data payload to be sent with the notification.
  /// [providerConfig]: The specific configuration for the provider
  /// (e.g., FirebaseProviderConfig, OneSignalProviderConfig).
  Future<void> sendNotification({
    required String deviceToken,
    required PushNotificationPayload payload,
    required PushNotificationProviderConfig providerConfig,
  });
}
