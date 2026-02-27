import 'dart:async';

import 'package:core/core.dart';

import 'package:flutter_news_app_backend_api_full_source_code/src/services/push_notification/push_notification_client.dart';
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
    required DataRepository<AppSettings> appSettingsRepository,
    required DataRepository<InAppNotification> inAppNotificationRepository,
    required IPushNotificationClient? firebaseClient,
    required IPushNotificationClient? oneSignalClient,
    required Logger log,
  }) : _pushNotificationDeviceRepository = pushNotificationDeviceRepository,
       _userContentPreferencesRepository = userContentPreferencesRepository,
       _remoteConfigRepository = remoteConfigRepository,
       _appSettingsRepository = appSettingsRepository,
       _inAppNotificationRepository = inAppNotificationRepository,
       _firebaseClient = firebaseClient,
       _oneSignalClient = oneSignalClient,
       _log = log;

  final DataRepository<PushNotificationDevice>
  _pushNotificationDeviceRepository;
  final DataRepository<UserContentPreferences>
  _userContentPreferencesRepository;
  final DataRepository<RemoteConfig> _remoteConfigRepository;
  final DataRepository<AppSettings> _appSettingsRepository;
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
      'Attempting to send breaking news notification for headline ID: ${headline.id}.',
    );

    try {
      // 1. Fetch RemoteConfig to get push notification settings.
      final remoteConfig = await _remoteConfigRepository.read(
        id: _remoteConfigId,
      );
      _log.finer(
        'Fetched remote config for push notification settings successfully.',
      );
      final pushConfig = remoteConfig.features.pushNotifications;

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
      if (primaryProvider == PushNotificationProviders.firebase) {
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
      final allSubscribedUserPreferences = <UserContentPreferences>[];
      String? cursor;
      var hasMore = true;

      while (hasMore) {
        final page = await _userContentPreferencesRepository.readAll(
          filter: {
            'savedHeadlineFilters.deliveryTypes': {
              r'$in': [
                PushNotificationSubscriptionDeliveryType.breakingOnly.name,
              ],
            },
          },
          pagination: PaginationOptions(cursor: cursor, limit: 100),
        );
        allSubscribedUserPreferences.addAll(page.items);
        cursor = page.cursor;
        hasMore = page.hasMore;
      }

      _log.finer(
        'Found ${allSubscribedUserPreferences.length} total users with at least one breaking news subscription.',
      );
      if (allSubscribedUserPreferences.isEmpty) {
        _log.info('No users subscribed to breaking news. Aborting.');
        return;
      }

      // 3. Filter these users to find who should receive THIS specific notification.
      final eligibleUserIds = allSubscribedUserPreferences
          .where(
            (preference) => preference.savedHeadlineFilters.any(
              (filter) => _matchesCriteria(headline: headline, filter: filter),
            ),
          )
          .map((preference) => preference.id)
          .toSet();
      _log.finer(
        'Filtered down to ${eligibleUserIds.length} users matching headline criteria.',
      );

      if (eligibleUserIds.isEmpty) {
        _log.info(
          'No users matched the criteria for this specific breaking news headline. Aborting.',
        );
        return;
      }

      _log.info(
        'Found ${eligibleUserIds.length} eligible users for this breaking news headline.',
      );

      // 4. Fetch AppSettings for all eligible users to determine their
      // preferred language.
      final allAppSettings = <AppSettings>[];
      String? settingsCursor;
      var settingsHasMore = true;

      while (settingsHasMore) {
        final page = await _appSettingsRepository.readAll(
          filter: {
            'id': {r'$in': eligibleUserIds.toList()},
          },
          pagination: PaginationOptions(cursor: settingsCursor, limit: 1000),
        );
        allAppSettings.addAll(page.items);
        settingsCursor = page.cursor;
        settingsHasMore = page.hasMore;
      }

      // Create a lookup map from userId to their preferred language.
      final userLanguageMap = {
        for (final settings in allAppSettings) settings.id: settings.language,
      };
      _log.finer(
        'Fetched ${userLanguageMap.length} AppSettings for language preferences.',
      );

      // Fetch the default language from remote config as a fallback.
      final defaultLanguage = remoteConfig.app.localization.defaultLanguage;

      // 5. Fetch all devices for all subscribed users using pagination.
      final allDevices = <PushNotificationDevice>[];
      String? devicesCursor;
      var devicesHasMore = true;

      while (devicesHasMore) {
        final page = await _pushNotificationDeviceRepository.readAll(
          filter: {
            'userId': {r'$in': eligibleUserIds.toList()},
          },
          pagination: PaginationOptions(cursor: devicesCursor, limit: 1000),
        );
        allDevices.addAll(page.items);
        devicesCursor = page.cursor;
        devicesHasMore = page.hasMore;
      }

      _log.finer(
        'Fetched ${allDevices.length} total devices for eligible users.',
      );
      if (allDevices.isEmpty) {
        _log.info('No registered devices found for any subscribed users.');
        return;
      }

      _log.info(
        'Found ${allDevices.length} total devices for subscribed users.',
      );

      // 6. Filter devices to include only those that have a token for the
      // system's primary provider.
      final targetedDevices = allDevices
          .where((d) => d.providerTokens.containsKey(primaryProvider))
          .toList();

      _log.finer(
        'Filtered down to ${targetedDevices.length} devices with a token for the primary provider.',
      );
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

      // 7. Group device tokens by user ID for efficient lookup.
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
      _log.finer(
        'Grouped ${targetedDevices.length} tokens by ${userDeviceTokensMap.keys.length} users.',
      );

      // 8. Iterate through each subscribed user to create and send a
      // personalized notification.
      final notificationsToCreate = <InAppNotification>[];

      for (final userId in eligibleUserIds) {
        final userDeviceTokens = userDeviceTokensMap[userId];
        if (userDeviceTokens != null && userDeviceTokens.isNotEmpty) {
          final notificationId = ObjectId();

          final String? imageUrlToSend;
          if (_isBase64Image(headline.imageUrl)) {
            _log.warning(
              'Headline ${headline.id} has a Base64 image. Omitting image from push notification payload to avoid exceeding size limits.',
            );
            imageUrlToSend = null;
          } else {
            imageUrlToSend = headline.imageUrl;
          }
          _log.finer(
            'User $userId has ${userDeviceTokens.length} devices. Creating in-app notification.',
          );

          // SERVER-SIDE RESOLUTION: Determine the correct title string.
          final userLanguage = userLanguageMap[userId] ?? defaultLanguage;
          final resolvedTitle =
              headline.title[userLanguage] ??
              headline.title[defaultLanguage] ??
              // Absolute fallback to the first available title.
              headline.title.values.first;

          final notification = InAppNotification(
            id: notificationId.oid,
            userId: userId,
            payload: PushNotificationPayload(
              // Corrected payload structure
              title: resolvedTitle,
              imageUrl: imageUrlToSend,
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

      // 9. Create all InAppNotification documents in parallel.
      final createFutures = notificationsToCreate.map(
        (notification) =>
            _inAppNotificationRepository.create(item: notification),
      );
      await Future.wait(createFutures);
      _log.info(
        'Successfully created ${notificationsToCreate.length} in-app notifications.',
      );

      // 10. Dispatch all push notifications in parallel.
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

      _log.finer(
        'All push notification dispatches have been awaited.',
      );
      _log.info(
        'Successfully dispatched breaking news notification for headline: '
        '${headline.id}.',
      );
    } on HttpException {
      rethrow;
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
    PushNotificationProviders provider,
  ) async {
    try {
      if (invalidTokens.isEmpty) {
        _log.finer('No invalid tokens to clean up.');
        return;
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
      _log.finer(
        'Found ${devicesToDelete.items.length} device documents to delete based on ${invalidTokens.length} invalid tokens.',
      );

      // Delete the devices in parallel for better performance.
      final deleteFutures = devicesToDelete.items.map(
        (device) => _pushNotificationDeviceRepository.delete(id: device.id),
      );
      _log.finer(
        'Attempting to delete ${deleteFutures.length} device documents.',
      );
      await Future.wait(deleteFutures);

      _log.info('Successfully cleaned up invalid device tokens.');
    } catch (e, s) {
      _log.severe('Failed to clean up invalid device tokens.', e, s);
      // We log the error but do not rethrow, as this is a background
      // cleanup task and should not crash the main application flow.
    }
  }

  bool _isBase64Image(String? url) {
    return url?.startsWith('data:image/') ?? false;
  }

  /// Checks if a given [headline] matches the criteria of a [filter].
  bool _matchesCriteria({
    required Headline headline,
    required SavedHeadlineFilter filter,
  }) {
    // 1. The filter must be subscribed to breaking news.
    if (!filter.deliveryTypes.contains(
      PushNotificationSubscriptionDeliveryType.breakingOnly,
    )) {
      return false;
    }

    // 2. Check topic match (wildcard if empty).
    final topicMatch =
        filter.criteria.topics.isEmpty ||
        filter.criteria.topics.any((t) => t.id == headline.topic.id);

    // 3. Check source match (wildcard if empty).
    final sourceMatch =
        filter.criteria.sources.isEmpty ||
        filter.criteria.sources.any((s) => s.id == headline.source.id);

    // 4. Check country match (wildcard if empty).
    final countryMatch =
        filter.criteria.countries.isEmpty ||
        filter.criteria.countries.any((c) => c.id == headline.eventCountry.id);

    return topicMatch && sourceMatch && countryMatch;
  }
}
