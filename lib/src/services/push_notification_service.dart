import 'dart:async';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/push_notification_client.dart';
import 'package:logging/logging.dart';

/// An abstract interface for the push notification service.
///
/// This service orchestrates the process of sending push notifications,
/// abstracting away the details of specific providers and data retrieval.
abstract class IPushNotificationService {
  /// Sends a breaking news notification based on the provided [headline].
  ///
  /// This method is responsible for identifying relevant user subscriptions,
  /// fetching device tokens, and dispatching the notification through the
  /// appropriate push notification client.
  Future<void> sendBreakingNewsNotification({required Headline headline});
}

/// {@template default_push_notification_service}
/// A concrete implementation of [IPushNotificationService] that handles
/// the end-to-end process of sending push notifications.
///
/// This service integrates with various data repositories to fetch user
/// subscriptions, device registrations, and remote configuration. It then
/// uses specific [IPushNotificationClient] implementations to send the
/// actual notifications.
/// {@endtemplate}
class DefaultPushNotificationService implements IPushNotificationService {
  /// {@macro default_push_notification_service}
  DefaultPushNotificationService({
    required DataRepository<PushNotificationDevice>
    pushNotificationDeviceRepository,
    required DataRepository<PushNotificationSubscription>
    pushNotificationSubscriptionRepository,
    required DataRepository<User> userRepository,
    required DataRepository<RemoteConfig> remoteConfigRepository,
    required IPushNotificationClient firebaseClient,
    required IPushNotificationClient oneSignalClient,
    required Logger log,
  }) : _pushNotificationDeviceRepository = pushNotificationDeviceRepository,
       _pushNotificationSubscriptionRepository =
           pushNotificationSubscriptionRepository,
       _userRepository = userRepository,
       _remoteConfigRepository = remoteConfigRepository,
       _firebaseClient = firebaseClient,
       _oneSignalClient = oneSignalClient,
       _log = log;

  final DataRepository<PushNotificationDevice>
  _pushNotificationDeviceRepository;
  final DataRepository<PushNotificationSubscription>
  _pushNotificationSubscriptionRepository;
  final DataRepository<User> _userRepository;
  final DataRepository<RemoteConfig> _remoteConfigRepository;
  final IPushNotificationClient _firebaseClient;
  final IPushNotificationClient _oneSignalClient;
  final Logger _log;

  // Assuming a fixed ID for the RemoteConfig document
  static const String _remoteConfigId = kRemoteConfigId;

  @override
  Future<void> sendBreakingNewsNotification({
    required Headline headline,
  }) async {
    _log.info(
      'Attempting to send breaking news notification for headline: '
      '"${headline.title}" (ID: ${headline.id}).',
    );

    try {
      // 1. Fetch RemoteConfig to get push notification settings.
      final remoteConfig = await _remoteConfigRepository.read(
        id: _remoteConfigId,
      );
      final pushConfig = remoteConfig.pushNotificationConfig;

      // Check if push notifications are globally enabled.
      if (!pushConfig.enabled) {
        _log.info('Push notifications are globally disabled. Aborting.');
        return;
      }

      // Check if breaking news notifications are enabled.
      final breakingNewsDeliveryConfig =
          pushConfig.deliveryConfigs[PushNotificationSubscriptionDeliveryType
              .breakingOnly];
      if (breakingNewsDeliveryConfig == null ||
          !breakingNewsDeliveryConfig.enabled) {
        _log.info('Breaking news notifications are disabled. Aborting.');
        return;
      }

      // Determine the primary push notification provider and its configuration.
      final primaryProvider = pushConfig.primaryProvider;
      final providerConfig = pushConfig.providerConfigs[primaryProvider];

      if (providerConfig == null) {
        _log.severe(
          'No configuration found for primary push notification provider: '
          '$primaryProvider. Cannot send notification.',
        );
        throw const OperationFailedException(
          'Push notification provider not configured.',
        );
      }

      // Select the appropriate client based on the primary provider.
      final IPushNotificationClient client;
      switch (primaryProvider) {
        case PushNotificationProvider.firebase:
          client = _firebaseClient;
          break;
        case PushNotificationProvider.oneSignal:
          client = _oneSignalClient;
          break;
      }

      // 2. Find all subscriptions for breaking news.
      // Filter for subscriptions that explicitly include 'breakingOnly'
      // in their deliveryTypes.
      final breakingNewsSubscriptions =
          await _pushNotificationSubscriptionRepository.readAll(
            filter: {
              'deliveryTypes': PushNotificationSubscriptionDeliveryType
                  .breakingOnly
                  .name, // Filter by enum name
            },
          );

      if (breakingNewsSubscriptions.items.isEmpty) {
        _log.info('No users subscribed to breaking news. Aborting.');
        return;
      }

      _log.info(
        'Found ${breakingNewsSubscriptions.items.length} subscriptions '
        'for breaking news.',
      );

      // 3. For each subscription, find the user's registered devices.
      for (final subscription in breakingNewsSubscriptions.items) {
        _log.finer(
          'Processing subscription ${subscription.id} for user ${subscription.userId}.',
        );

        // Fetch devices for the user associated with this subscription.
        final userDevices = await _pushNotificationDeviceRepository.readAll(
          filter: {'userId': subscription.userId},
        );

        if (userDevices.items.isEmpty) {
          _log.finer(
            'User ${subscription.userId} has no registered devices. Skipping.',
          );
          continue;
        }

        _log.finer(
          'User ${subscription.userId} has ${userDevices.items.length} devices.',
        );

        // 4. Construct the notification payload.
        final payload = PushNotificationPayload(
          title: headline.title,
          body: headline.excerpt,
          imageUrl: headline.imageUrl,
          data: {
            'headlineId': headline.id,
            'contentType': 'headline',
            'notificationType':
                PushNotificationSubscriptionDeliveryType.breakingOnly.name,
          },
        );

        // 5. Send notification to each device.
        for (final device in userDevices.items) {
          _log.finer(
            'Sending notification to device ${device.id} '
            '(${device.platform.name}) via ${device.provider.name}.',
          );
          // Note: We use the client determined by the primary provider,
          // not necessarily the device's registered provider, for consistency.
          await client.sendNotification(
            deviceToken: device.token,
            payload: payload,
            providerConfig: providerConfig,
          );
          _log.finer('Notification sent to device ${device.id}.');
        }
      }
      _log.info(
        'Finished processing breaking news notification for headline: '
        '"${headline.title}" (ID: ${headline.id}).',
      );
    } on HttpException {
      rethrow; // Propagate known HTTP exceptions
    } catch (e, s) {
      _log.severe(
        'Failed to send breaking news notification for headline ${headline.id}: $e',
        e,
        s,
      );
      throw OperationFailedException(
        'An internal error occurred while sending breaking news notification.',
      );
    }
  }
}
