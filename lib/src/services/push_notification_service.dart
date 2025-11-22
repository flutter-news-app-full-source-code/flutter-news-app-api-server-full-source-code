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

      // 7. Iterate through each subscribed user to create and send a
      // personalized notification.
      final sendFutures = <Future<void>>[];
      for (final userId in userIds) {
        // Create the InAppNotification record first to get its unique ID.
        final notificationId = ObjectId();
        final notification = InAppNotification(
          id: notificationId.oid,
          userId: userId,
          payload: PushNotificationPayload(
            title: headline.title,
            body: headline.excerpt,
            imageUrl: headline.imageUrl,
            data: {
              'notificationType':
                  PushNotificationSubscriptionDeliveryType.breakingOnly.name,
              'contentType': 'headline',
              'headlineId': headline.id,
              'notificationId': notificationId.oid,
            },
          ),
          createdAt: DateTime.now(),
        );

        try {
          await _inAppNotificationRepository.create(item: notification);

          // Find all device tokens for the current user.
          final userDeviceTokens = targetedDevices
              .where((d) => d.userId == userId)
              .map((d) => d.providerTokens[primaryProvider]!)
              .toList();

          if (userDeviceTokens.isNotEmpty) {
            // Add the send operation to the list of futures.
            sendFutures.add(
              client.sendBulkNotifications(
                deviceTokens: userDeviceTokens,
                payload: notification.payload,
              ),
            );
          }
        } catch (e, s) {
          _log.severe('Failed to process notification for user $userId.', e, s);
        }
      }

      // Await all the send operations to complete in parallel.
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
}
