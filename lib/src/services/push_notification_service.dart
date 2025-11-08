import 'dart:async';

import 'package:collection/collection.dart';
import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
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
      if (pushConfig == null || !pushConfig.enabled) {
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

      // 2. Find all subscriptions for breaking news.
      // The query now correctly finds subscriptions where 'deliveryTypes'
      // array *contains* the 'breakingOnly' value.
      final breakingNewsSubscriptions =
          await _pushNotificationSubscriptionRepository.readAll(
            filter: {
              'deliveryTypes': {
                r'$in': [
                  PushNotificationSubscriptionDeliveryType.breakingOnly.name,
                ],
              },
            },
          );

      if (breakingNewsSubscriptions.items.isEmpty) {
        _log.info('No users subscribed to breaking news. Aborting.');
        return;
      }

      // 3. Collect all unique user IDs from the subscriptions.
      // Using a Set automatically handles deduplication.
      final userIds = breakingNewsSubscriptions.items
          .map((sub) => sub.userId)
          .toSet();

      _log.info(
        'Found ${breakingNewsSubscriptions.items.length} subscriptions for '
        'breaking news, corresponding to ${userIds.length} unique users.',
      );

      // 4. Fetch all devices for all subscribed users in a single bulk query.
      final allDevicesResponse = await _pushNotificationDeviceRepository
          .readAll(
            filter: {
              'userId': {r'$in': userIds.toList()},
            },
          );

      final allDevices = allDevicesResponse.items;
      if (allDevices.isEmpty) {
        _log.info('No registered devices found for any subscribed users.');
        return;
      }

      _log.info(
        'Found ${allDevices.length} total devices for subscribed users.',
      );

      // 5. Group devices by their registered provider (Firebase or OneSignal).
      // This is crucial because a device must be notified via the provider
      // it registered with, regardless of the system's primary provider.
      final devicesByProvider = allDevices.groupListsBy((d) => d.provider);

      // 6. Construct the notification payload.
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

      // 7. Dispatch notifications in bulk for each provider group.
      await Future.wait([
        if (devicesByProvider.containsKey(PushNotificationProvider.firebase))
          _sendToFirebase(
            devices: devicesByProvider[PushNotificationProvider.firebase]!,
            payload: payload,
          ),
        if (devicesByProvider.containsKey(PushNotificationProvider.oneSignal))
          _sendToOneSignal(
            devices: devicesByProvider[PushNotificationProvider.oneSignal]!,
            payload: payload,
          ),
      ]);

      _log.info(
        'Finished processing breaking news notification for headline: '
        '"${headline.title}" (ID: ${headline.id}).',
      );
    } on HttpException {
      rethrow; // Propagate known HTTP exceptions
    } catch (e, s) {
      _log.severe(
        'Failed to send breaking news notification for headline '
        '${headline.id}: $e',
        e,
        s,
      );
      throw OperationFailedException(
        'An internal error occurred while sending breaking news notification.',
      );
    }
  }

  Future<void> _sendToFirebase({
    required List<PushNotificationDevice> devices,
    required PushNotificationPayload payload,
  }) async {
    final tokens = devices.map((d) => d.token).toList();
    _log.info('Sending notification to ${tokens.length} Firebase devices.');
    await _firebaseClient.sendBulkNotifications(
      deviceTokens: tokens,
      payload: payload,
      // The provider config is now created on-the-fly using non-sensitive
      // data from environment variables, not from RemoteConfig.
      providerConfig: FirebaseProviderConfig(
        projectId: EnvironmentConfig.firebaseProjectId,
        // These fields are not used by the client but are required by the
        // model. They will be removed in a future refactor.
        clientEmail: '',
        privateKey: '',
      ),
    );
  }

  Future<void> _sendToOneSignal({
    required List<PushNotificationDevice> devices,
    required PushNotificationPayload payload,
  }) async {
    final tokens = devices.map((d) => d.token).toList();
    _log.info('Sending notification to ${tokens.length} OneSignal devices.');
    await _oneSignalClient.sendBulkNotifications(
      deviceTokens: tokens,
      payload: payload,
      // The provider config is now created on-the-fly using non-sensitive
      // data from environment variables, not from RemoteConfig.
      providerConfig: OneSignalProviderConfig(
        appId: EnvironmentConfig.oneSignalAppId,
        // This field is not used by the client but is required by the
        // model. It will be removed in a future refactor.
        restApiKey: '',
      ),
    );
  }
}
