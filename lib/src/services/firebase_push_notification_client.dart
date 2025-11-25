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
  Future<PushNotificationResult> sendNotification({
    required String deviceToken,
    required PushNotificationPayload payload,
  }) {
    // For consistency, the single send method now delegates to the bulk
    // method with a list containing just one token.
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
      _log.info('No device tokens provided for Firebase bulk send. Aborting.');
      return const PushNotificationResult(
        sentTokens: [],
        failedTokens: [],
      );
    }
    _log.info(
      'Sending Firebase bulk notification to ${deviceTokens.length} devices '
      'for project "$projectId".',
    );

    // The FCM v1 batch API has a limit of 500 messages per request.
    // We must chunk the tokens into batches of this size.
    const batchSize = 500;
    final allSentTokens = <String>[];
    final allFailedTokens = <String>[];

    for (var i = 0; i < deviceTokens.length; i += batchSize) {
      final batch = deviceTokens.sublist(
        i,
        i + batchSize > deviceTokens.length
            ? deviceTokens.length
            : i + batchSize,
      );

      // Send each chunk as a separate batch request.
      final batchResult = await _sendBatch(
        batchNumber: (i ~/ batchSize) + 1,
        totalBatches: (deviceTokens.length / batchSize).ceil(),
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

  /// Sends a batch of notifications by dispatching individual requests in
  /// parallel.
  ///
  /// This method processes the results to distinguish between successful and
  /// failed sends, returning a [PushNotificationResult].
  Future<PushNotificationResult> _sendBatch({
    required int batchNumber,
    required int totalBatches,
    required List<String> deviceTokens,
    required PushNotificationPayload payload,
  }) async {
    // The base URL is configured in app_dependencies.dart.
    // The final URL will be:
    // `https://fcm.googleapis.com/v1/projects/<projectId>/messages:send`
    const url = 'messages:send';
    _log.info(
      'Sending Firebase batch $batchNumber of $totalBatches '
      'to ${deviceTokens.length} devices.',
    );

    // Create a list of futures, one for each notification to be sent.
    final sendFutures = deviceTokens.map((token) {
      final requestBody = {
        'message': {
          'token': token,
          'notification': {
            'title': payload.title,
            'body': payload.title,
            if (payload.imageUrl != null) 'image': payload.imageUrl,
          },
          // Reconstruct the data payload from the explicit fields
          'data': {
            'notificationId': payload.notificationId,
            'notificationType': payload.notificationType.name,
            'contentType': payload.contentType.name,
            'contentId': payload.contentId,
          },
        },
      };

      // Return the future from the post request.
      return _httpClient.post<void>(url, data: requestBody);
    }).toList();

    // `eagerError: false` ensures that all futures complete, even if some
    // fail. The results list will contain Exception objects for failures.
    final results = await Future.wait<dynamic>(
      sendFutures,
      eagerError: false,
    );

    final sentTokens = <String>[];
    final failedTokens = <String>[];

    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      final token = deviceTokens[i];

      if (result is Exception) {
        if (result is NotFoundException) {
          // This is the only case where we treat the token as permanently
          // invalid and mark it for cleanup.
          failedTokens.add(token);
          _log.info(
            'Batch $batchNumber/$totalBatches: Failed to send to an '
            'invalid/unregistered token: ${result.message}',
          );
        } else if (result is HttpException) {
          // For other HTTP errors (e.g., 500), we log it as severe but do
          // not mark the token for deletion as the error may be transient.
          _log.severe(
            'Batch $batchNumber/$totalBatches: HTTP error sending '
            'Firebase notification to token "$token": ${result.message}',
            result,
          );
        } else {
          // For any other unexpected exception.
          _log.severe(
            'Unexpected error sending Firebase notification to token "$token".',
            result,
          );
        }
      } else {
        // If there's no exception, the send was successful.
        sentTokens.add(token);
      }
    }
    _log.info(
      'Firebase batch $batchNumber/$totalBatches complete. Success: ${sentTokens.length}, Failed: ${failedTokens.length}.',
    );
    return PushNotificationResult(
      sentTokens: sentTokens,
      failedTokens: failedTokens,
    );
  }
}
