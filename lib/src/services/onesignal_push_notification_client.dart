import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart';
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
  Future<PushNotificationResult> sendNotification({
    required String deviceToken,
    required PushNotificationPayload payload,
  }) {
    // For consistency, delegate to the bulk sending method with a single token.
    return sendBulkNotifications(
      deviceTokens: [deviceToken],
      payload: payload,
    );
  }

  @override
  Future<PushNotificationResult> sendBulkNotifications({
    required List<String> deviceTokens,
    required PushNotificationPayload payload,
  }) async {
    if (deviceTokens.isEmpty) {
      _log.info('No device tokens provided for OneSignal bulk send. Aborting.');
      return const PushNotificationResult();
    }

    _log.info(
      'Sending OneSignal bulk notification to ${deviceTokens.length} '
      'devices for app ID "$appId".',
    );

    // OneSignal has a limit of 2000 player_ids per API request.
    const batchSize = 2000;
    final allSentTokens = <String>[];
    final allFailedTokens = <String>[];

    for (var i = 0; i < deviceTokens.length; i += batchSize) {
      final batch = deviceTokens.sublist(
        i,
        i + batchSize > deviceTokens.length
            ? deviceTokens.length
            : i + batchSize,
      );

      final batchResult = await _sendBatch(
        deviceTokens: batch,
        payload: payload,
      );

      allSentTokens.addAll(batchResult.sentTokens);
      allFailedTokens.addAll(batchResult.failedTokens);
    }

    return PushNotificationResult(
      sentTokens: allSentTokens,
      failedTokens: allFailedTokens,
    );
  }

  /// Sends a single batch of notifications to the OneSignal API.
  ///
  /// This method processes the API response to distinguish between successful
  /// and failed sends, returning a [PushNotificationResult].
  Future<PushNotificationResult> _sendBatch({
    required List<String> deviceTokens,
    required PushNotificationPayload payload,
  }) async {
    // The REST API key is provided by the HttpClient's tokenProvider and
    // injected by its AuthInterceptor. The base URL is also configured in
    // app_dependencies.dart. The final URL will be: `https://onesignal.com/api/v1/notifications`
    const url = 'notifications';

    _log.finer(
      'Sending OneSignal batch of ${deviceTokens.length} notifications.',
    );

    final requestBody = OneSignalRequestBody(
      appId: appId,
      includePlayerIds: deviceTokens,
      headings: {'en': payload.title},
      contents: {'en': payload.title},
      bigPicture: payload.imageUrl,
      data: payload,
    );

    try {
      // The OneSignal API returns a JSON object with details about the send,
      // including errors for invalid player IDs.
      final response = await _httpClient.post<Map<String, dynamic>>(
        url,
        data: requestBody,
      );

      final sentTokens = <String>{...deviceTokens};
      final failedTokens = <String>{};

      // Check for errors in the response body.
      if (response.containsKey('errors') && response['errors'] != null) {
        final errors = response['errors'];
        if (errors is Map && errors.containsKey('invalid_player_ids')) {
          final invalidIds = List<String>.from(
            errors['invalid_player_ids'] as List,
          );
          if (invalidIds.isNotEmpty) {
            _log.info(
              'OneSignal reported ${invalidIds.length} invalid player IDs. '
              'These will be marked as failed.',
            );
            failedTokens.addAll(invalidIds);
            sentTokens.removeAll(invalidIds);
          }
        }
      }

      _log.info(
        'OneSignal batch complete. Success: ${sentTokens.length}, '
        'Failed: ${failedTokens.length}.',
      );
      return PushNotificationResult(
        sentTokens: sentTokens.toList(),
        failedTokens: failedTokens.toList(),
      );
    } on HttpException catch (e) {
      _log.severe(
        'HTTP error sending OneSignal batch notification: ${e.message}',
        e,
      );
      // If the entire request fails, all tokens in this batch are considered failed.
      return PushNotificationResult(failedTokens: deviceTokens);
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
