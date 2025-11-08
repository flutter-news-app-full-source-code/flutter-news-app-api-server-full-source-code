import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/push_notification_client.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';

/// A concrete implementation of [IPushNotificationClient] for sending
/// notifications via Firebase Cloud Messaging (FCM).
///
/// This client constructs and sends the appropriate HTTP request to the
/// FCM v1 API. It relies on an [HttpClient] that must be pre-configured
/// with an `AuthInterceptor` to handle the OAuth2 authentication required
/// by Google APIs.
class FirebasePushNotificationClient implements IPushNotificationClient {
  /// Creates an instance of [FirebasePushNotificationClient].
  ///
  /// Requires an [HttpClient] to make API requests and a [Logger] for logging.
  const FirebasePushNotificationClient({
    required this.projectId,
    required HttpClient httpClient,
    required Logger log,
  }) : _httpClient = httpClient,
       _log = log;

  /// The Firebase Project ID for push notifications.
  final String projectId;
  final HttpClient _httpClient;
  final Logger _log;

  @override
  Future<void> sendNotification({
    required String deviceToken,
    required PushNotificationPayload payload,
  }) async {
    // For consistency, the single send method now delegates to the bulk
    // method with a list containing just one token.
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
      _log.info('No device tokens provided for Firebase bulk send. Aborting.');
      return;
    }

    _log.info(
      'Sending Firebase bulk notification to ${deviceTokens.length} devices '
      'for project "$projectId".',
    );

    // The FCM v1 batch API has a limit of 500 messages per request.
    // We must chunk the tokens into batches of this size.
    const batchSize = 500;
    for (var i = 0; i < deviceTokens.length; i += batchSize) {
      final batch = deviceTokens.sublist(
        i,
        i + batchSize > deviceTokens.length
            ? deviceTokens.length
            : i + batchSize,
      );

      // Send each chunk as a separate batch request.
      await _sendBatch(deviceTokens: batch, payload: payload);
    }
  }

  /// Sends a batch of notifications by dispatching individual requests in
  /// parallel.
  ///
  /// This approach is simpler and more robust than using the `batch` endpoint,
  /// as it avoids the complexity of constructing a multipart request body and
  /// provides clearer error handling for individual message failures.
  Future<void> _sendBatch({
    required List<String> deviceTokens,
    required PushNotificationPayload payload,
  }) async {
    // The base URL is configured in app_dependencies.dart.
    // The final URL will be:
    // `https://fcm.googleapis.com/v1/projects/<projectId>/messages:send`
    const url = 'messages:send';

    // Create a list of futures, one for each notification to be sent.
    final sendFutures = deviceTokens.map((token) {
      final requestBody = {
        'message': {
          'token': token,
          'notification': {
            'title': payload.title,
            'body': payload.body,
            if (payload.imageUrl != null) 'image': payload.imageUrl,
          },
          'data': payload.data,
        },
      };

      // Return the future from the post request.
      return _httpClient.post<void>(url, data: requestBody);
    }).toList();

    try {
      // `eagerError: false` ensures that all futures complete, even if some
      // fail. The results list will contain Exception objects for failures.
      final results = await Future.wait<dynamic>(
        sendFutures,
        eagerError: false,
      );

      final failedResults = results.whereType<Exception>().toList();

      if (failedResults.isEmpty) {
        _log.info(
          'Successfully sent Firebase batch of ${deviceTokens.length} '
          'notifications for project "$projectId".',
        );
      } else {
        _log.warning(
          '${failedResults.length} out of ${deviceTokens.length} Firebase '
          'notifications failed to send in batch for project "$projectId".',
        );
        for (final error in failedResults) {
          if (error is HttpException) {
            _log.severe(
              'HTTP error sending Firebase notification: ${error.message}',
              error,
            );
          } else {
            _log.severe(
              'Unexpected error sending Firebase notification.',
              error,
            );
          }
        }
        // Throw an exception to indicate that the batch send was not fully successful.
        throw OperationFailedException(
          'Failed to send ${failedResults.length} Firebase notifications.',
        );
      }
    } catch (e, s) {
      _log.severe('Unexpected error processing Firebase batch results.', e, s);
      throw OperationFailedException('Failed to process Firebase batch: $e');
    }
  }
}
