import 'dart:async';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/push_notification_client.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

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
    required DataRepository<UserContentPreferences>
    userContentPreferencesRepository,
    required DataRepository<RemoteConfig> remoteConfigRepository,
    required DataRepository<InAppNotification> inAppNotificationRepository,
    required IPushNotificationClient? firebaseClient,
    required IPushNotificationClient? oneSignalClient,
    required Logger log,
  }) : _pushNotificationDeviceRepository = pushNotificationDeviceRepository,
       _userContentPreferencesRepository = userContentPreferencesRepository,
       _remoteConfigRepository = remoteConfigRepository,
       _inAppNotificationRepository = inAppNotificationRepository,
       _firebaseClient = firebaseClient,
       _oneSignalClient = oneSignalClient,
       _log = log;

  final DataRepository<PushNotificationDevice>
  _pushNotificationDeviceRepository;
  final DataRepository<UserContentPreferences>
  _userContentPreferencesRepository;
  final DataRepository<RemoteConfig> _remoteConfigRepository;
  final DataRepository<InAppNotification> _inAppNotificationRepository;
  final IPushNotificationClient? _firebaseClient;
  final IPushNotificationClient? _oneSignalClient;
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

      // Get the primary provider from the remote config. This is the single
      // source of truth for which provider to use.
      final primaryProvider = pushConfig.primaryProvider;
      _log.info(
        'Push notifications are enabled. Primary provider is "$primaryProvider".',
      );

      // Determine which client to use based on the primary provider.
      final IPushNotificationClient? client;
      if (primaryProvider == PushNotificationProvider.firebase) {
        client = _firebaseClient;
      } else {
        client = _oneSignalClient;
      }

      // CRITICAL: Check if the selected primary provider's client was
      // actually initialized. If not (due to missing .env credentials),
      // log a severe error and abort.
      if (client == null) {
        _log.severe(
          'Push notifications are enabled with "$primaryProvider" as the '
          'primary provider, but the client could not be initialized. '
          'Please ensure all required environment variables for this provider are set. Aborting.',
        );
        return;
      }

      // Check if breaking news notifications are enabled.
      final isBreakingNewsEnabled =
          pushConfig.deliveryConfigs[PushNotificationSubscriptionDeliveryType
              .breakingOnly] ??
          false;

      if (!isBreakingNewsEnabled) {
        _log.info('Breaking news notifications are disabled. Aborting.');
        return;
      }

      // 2. Find all user preferences that contain a saved headline filter
      //    subscribed to breaking news. This query targets the embedded 'savedHeadlineFilters' array.
      final subscribedUserPreferences = await _userContentPreferencesRepository
          .readAll(
            filter: {
              'savedHeadlineFilters.deliveryTypes': {
                r'$in': [
                  PushNotificationSubscriptionDeliveryType.breakingOnly.name,
                ],
              },
            },
          );

      if (subscribedUserPreferences.items.isEmpty) {
        _log.info('No users subscribed to breaking news. Aborting.');
        return;
      }

      // 3. Collect all unique user IDs from the preference documents.
      // Using a Set automatically handles deduplication.
      // The ID of the UserContentPreferences document is the user's ID.
      final userIds = subscribedUserPreferences.items
          .map((preference) => preference.id)
          .toSet();

      _log.info(
        'Found ${subscribedUserPreferences.items.length} users with '
        'subscriptions to breaking news.',
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

      // 5. Filter devices to include only those that have a token for the
      // system's primary provider.
      final targetedDevices = allDevices
          .where((d) => d.providerTokens.containsKey(primaryProvider))
          .toList();

      if (targetedDevices.isEmpty) {
        _log.info(
          'No devices found with a token for the primary provider '
          '("$primaryProvider"). Aborting.',
        );
        return;
      }

      _log.info(
        'Found ${targetedDevices.length} devices to target via $primaryProvider.',
      );

      // 6. Group device tokens by user ID for efficient lookup.
      // This avoids iterating through all devices for each user.
      final userDeviceTokensMap = <String, List<String>>{};
      for (final device in targetedDevices) {
        final token = device.providerTokens[primaryProvider];
        if (token != null) {
          // The `putIfAbsent` method provides a concise way to ensure the list
          // exists before adding the token to it.
          userDeviceTokensMap.putIfAbsent(device.userId, () => []).add(token);
        }
      }

      // 7. Iterate through each subscribed user to create and send a
      // personalized notification.
      final notificationsToCreate = <InAppNotification>[];

      for (final userId in userIds) {
        final userDeviceTokens = userDeviceTokensMap[userId];
        if (userDeviceTokens != null && userDeviceTokens.isNotEmpty) {
          final notificationId = ObjectId();
          final notification = InAppNotification(
            id: notificationId.oid,
            userId: userId,
            payload: PushNotificationPayload(
              // Corrected payload structure
              title: headline.title,
              imageUrl: headline.imageUrl,
              notificationId: notificationId.oid,
              notificationType:
                  PushNotificationSubscriptionDeliveryType.breakingOnly,
              contentType: ContentType.headline,
              contentId: headline.id,
            ),
            createdAt: DateTime.now(),
          );
          notificationsToCreate.add(notification);
        }
      }

      // 8. Create all InAppNotification documents in parallel.
      final createFutures = notificationsToCreate.map(
        (notification) =>
            _inAppNotificationRepository.create(item: notification),
      );
      await Future.wait(createFutures);
      _log.info(
        'Successfully created ${notificationsToCreate.length} in-app notifications.',
      );

      // 9. Dispatch all push notifications in parallel.
      final sendFutures = notificationsToCreate.map((notification) {
        final userDeviceTokens = userDeviceTokensMap[notification.userId] ?? [];
        return client!
            .sendBulkNotifications(
              deviceTokens: userDeviceTokens,
              payload: notification.payload,
            )
            .then((result) {
              // After the send completes, trigger the cleanup process for
              // any failed tokens. This is a fire-and-forget operation.
              unawaited(
                _cleanupInvalidDevices(result.failedTokens, primaryProvider),
              );
            });
      });

      // Await all the send operations to complete.
      await Future.wait(sendFutures);

      _log.info(
        'Successfully dispatched breaking news notification for headline: '
        '${headline.id}.',
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
      throw const OperationFailedException(
        'An internal error occurred while sending breaking news notification.',
      );
    }
  }

  /// Deletes device registrations associated with a list of invalid tokens.
  ///
  /// This method is called after a push notification send operation to prune
  /// the database of tokens that the provider has identified as unregistered
  /// or invalid (e.g., because the app was uninstalled).
  ///
  /// - [invalidTokens]: A list of device tokens that failed to be delivered.
  /// - [provider]: The push notification provider that reported the tokens as
  ///   invalid.
  Future<void> _cleanupInvalidDevices(
    List<String> invalidTokens,
    PushNotificationProvider provider,
  ) async {
    if (invalidTokens.isEmpty) {
      return; // Nothing to clean up.
    }

    _log.info(
      'Cleaning up ${invalidTokens.length} invalid device tokens for provider "$provider".',
    );

    // Retrieve the list of devices that match the filter criteria.
    final devicesToDelete = await _pushNotificationDeviceRepository.readAll(
      filter: {
        'providerTokens.${provider.name}': {r'$in': invalidTokens},
      },
    );

    try {
      // Delete the devices in parallel for better performance.
      final deleteFutures = devicesToDelete.items.map(
        (device) => _pushNotificationDeviceRepository.delete(id: device.id),
      );
      await Future.wait(deleteFutures);

      _log.info('Successfully cleaned up invalid device tokens.');
    } catch (e, s) {
      _log.severe('Failed to clean up invalid device tokens.', e, s);
      // We log the error but do not rethrow, as this is a background
      // cleanup task and should not crash the main application flow.
    }
  }
}
