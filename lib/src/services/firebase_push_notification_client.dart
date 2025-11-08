import 'dart:convert';

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
    required HttpClient httpClient,
    required Logger log,
  })  : _httpClient = httpClient,
        _log = log;

  final HttpClient _httpClient;
  final Logger _log;

  @override
  Future<void> sendNotification({
    required String deviceToken,
    required PushNotificationPayload payload,
    required PushNotificationProviderConfig providerConfig,
  }) async {
    // For consistency, the single send method now delegates to the bulk
    // method with a list containing just one token.
    await sendBulkNotifications(
      deviceTokens: [deviceToken],
      payload: payload,
      providerConfig: providerConfig,
    );
  }

  @override
  Future<void> sendBulkNotifications({
    required List<String> deviceTokens,
    required PushNotificationPayload payload,
    required PushNotificationProviderConfig providerConfig,
  }) async {
    if (providerConfig is! FirebaseProviderConfig) {
      _log.severe(
        'Invalid provider config type: ${providerConfig.runtimeType}. '
        'Expected FirebaseProviderConfig.',
      );
      throw const OperationFailedException(
        'Internal config error for Firebase push notification client.',
      );
    }

    if (deviceTokens.isEmpty) {
      _log.info('No device tokens provided for Firebase bulk send. Aborting.');
      return;
    }

    _log.info(
      'Sending Firebase bulk notification to ${deviceTokens.length} '
      'devices for project "${providerConfig.projectId}".',
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
      await _sendBatch(
        deviceTokens: batch,
        payload: payload,
        providerConfig: providerConfig,
      );
    }
  }

  /// Sends a single batch of notifications to the FCM v1 batch endpoint.
  ///
  /// This method constructs a `multipart/mixed` request body, where each part
  /// is a complete HTTP POST request to the standard `messages:send` endpoint.
  Future<void> _sendBatch({
    required List<String> deviceTokens,
    required PushNotificationPayload payload,
    required FirebaseProviderConfig providerConfig,
  }) async {
    const boundary = 'batch_boundary';
    // The FCM v1 batch endpoint is at a different path. We must use a full
    // URL here to override the HttpClient's default base URL.
    const batchUrl = 'https://fcm.googleapis.com/batch';

    // Map each device token to its corresponding sub-request string.
    final subrequests = deviceTokens.map((token) {
      // Construct the JSON body for a single message.
      final messageBody = jsonEncode({
        'message': {
          'token': token,
          'notification': {
            'title': payload.title,
            'body': payload.body,
            if (payload.imageUrl != null) 'image': payload.imageUrl,
          },
          'data': payload.data,
        },
      });

      // Construct the full HTTP request for this single message as a string.
      // This is the format required for each part of the multipart request.
      return '''
--$boundary
Content-Type: application/http
Content-Transfer-Encoding: binary

POST /v1/projects/${providerConfig.projectId}/messages:send
Content-Type: application/json
accept: application/json

$messageBody''';
    }).join('\n');

    // The final request body is the joined sub-requests followed by the
    // closing boundary marker.
    final batchRequestBody = '$subrequests\n--$boundary--';

    try {
      // Post the raw multipart body with the correct `Content-Type` header
      // to the specific batch endpoint URL.
      await _httpClient.post<void>(
        batchUrl,
        data: batchRequestBody,
        options: Options(
          headers: {'Content-Type': 'multipart/mixed; boundary=$boundary'},
        ),
      );
      _log.info(
        'Successfully sent Firebase batch of ${deviceTokens.length} '
        'notifications for project "${providerConfig.projectId}".',
      );
    } on HttpException catch (e) {
      _log.severe(
        'HTTP error sending Firebase batch notification: ${e.message}',
        e,
      );
      rethrow;
    } catch (e, s) {
      _log.severe(
        'Unexpected error sending Firebase batch notification.',
        e,
        s,
      );
      throw OperationFailedException(
        'Failed to send Firebase batch notification: $e',
      );
    }
  }
}
