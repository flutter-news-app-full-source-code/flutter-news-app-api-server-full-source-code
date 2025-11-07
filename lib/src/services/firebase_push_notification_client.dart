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
  }) : _httpClient = httpClient,
       _log = log;

  final HttpClient _httpClient;
  final Logger _log;

  @override
  Future<void> sendNotification({
    required String deviceToken,
    required PushNotificationPayload payload,
    required PushNotificationProviderConfig providerConfig,
  }) async {
    if (providerConfig is! FirebaseProviderConfig) {
      _log.severe(
        'Invalid provider config type: ${providerConfig.runtimeType}. '
        'Expected FirebaseProviderConfig.',
      );
      throw const OperationFailedException(
        'Internal configuration error for Firebase push notification client.',
      );
    }

    final projectId = providerConfig.projectId;
    final url = 'messages:send';

    _log.info(
      'Sending Firebase notification to token starting with '
      '"${deviceToken.substring(0, 10)}..." for project "$projectId".',
    );

    // Construct the FCM v1 API request body.
    final requestBody = {
      'message': {
        'token': deviceToken,
        'notification': {
          'title': payload.title,
          'body': payload.body,
          if (payload.imageUrl != null) 'image': payload.imageUrl,
        },
        // The 'data' payload is crucial for client-side handling,
        // such as deep-linking when the notification is tapped.
        'data': payload.data,
      },
    };

    try {
      await _httpClient.post(url, data: requestBody);
      _log.info(
        'Successfully sent Firebase notification for project "$projectId".',
      );
    } on HttpException catch (e) {
      _log.severe(
        'HTTP error sending Firebase notification: ${e.message}',
        e,
      );
      rethrow;
    }
  }
}
