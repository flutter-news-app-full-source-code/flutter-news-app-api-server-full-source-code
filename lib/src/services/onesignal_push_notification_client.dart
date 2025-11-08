import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/push_notification_client.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';

/// A concrete implementation of [IPushNotificationClient] for sending
/// notifications via the OneSignal REST API.
///
/// This client constructs and sends the appropriate HTTP request to the
/// OneSignal API. It relies on an [HttpClient] that must be pre-configured
/// with an `AuthInterceptor` to handle the `Authorization: Basic <REST_API_KEY>`
/// header required by OneSignal.
class OneSignalPushNotificationClient implements IPushNotificationClient {
  /// Creates an instance of [OneSignalPushNotificationClient].
  ///
  /// Requires an [HttpClient] to make API requests and a [Logger] for logging.
  const OneSignalPushNotificationClient({
    required this.appId,
    required HttpClient httpClient,
    required Logger log,
  }) : _httpClient = httpClient,
       _log = log;

  /// The OneSignal App ID for push notifications.
  final String appId;
  final HttpClient _httpClient;
  final Logger _log;

  @override
  Future<void> sendNotification({
    required String deviceToken,
    required PushNotificationPayload payload,
  }) async {
    // For consistency, delegate to the bulk sending method with a single token.
    await sendBulkNotifications(
      deviceTokens: [deviceToken],
      payload: payload,
    );
  }

  @override
  Future<void> sendBulkNotifications({
    required List<String> deviceTokens,
    required PushNotificationPayload payload,
  }) async {
    if (deviceTokens.isEmpty) {
      _log.info('No device tokens provided for OneSignal bulk send. Aborting.');
      return;
    }

    _log.info(
      'Sending OneSignal bulk notification to ${deviceTokens.length} '
      'devices for app ID "$appId".',
    );

    // OneSignal has a limit of 2000 player_ids per API request.
    const batchSize = 2000;
    for (var i = 0; i < deviceTokens.length; i += batchSize) {
      final batch = deviceTokens.sublist(
        i,
        i + batchSize > deviceTokens.length
            ? deviceTokens.length
            : i + batchSize,
      );

      await _sendBatch(
        deviceTokens: batch,
        payload: payload,
      );
    }
  }

  /// Sends a single batch of notifications to the OneSignal API.
  Future<void> _sendBatch({
    required List<String> deviceTokens,
    required PushNotificationPayload payload,
  }) async {
    // The REST API key is provided by the HttpClient's tokenProvider and
    // injected by its AuthInterceptor. The base URL is also configured in
    // app_dependencies.dart. The final URL will be: `https://onesignal.com/api/v1/notifications`
    const url = 'notifications';

    // Construct the OneSignal API request body.
    final requestBody = {
      'app_id': appId,
      'include_player_ids': deviceTokens,
      'headings': {'en': payload.title},
      'contents': {'en': payload.body},
      if (payload.imageUrl != null) 'big_picture': payload.imageUrl,
      'data': payload.data,
    };

    _log.finer(
      'Sending OneSignal batch of ${deviceTokens.length} notifications.',
    );

    try {
      await _httpClient.post<void>(url, data: requestBody);
      _log.info(
        'Successfully sent OneSignal batch of ${deviceTokens.length} '
        'notifications for app ID "$appId".',
      );
    } on HttpException catch (e) {
      _log.severe(
        'HTTP error sending OneSignal batch notification: ${e.message}',
        e,
      );
      rethrow;
    } catch (e, s) {
      _log.severe(
        'Unexpected error sending OneSignal batch notification.',
        e,
        s,
      );
      throw OperationFailedException(
        'Failed to send OneSignal batch notification: $e',
      );
    }
  }
}
