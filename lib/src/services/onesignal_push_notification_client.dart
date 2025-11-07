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
    if (providerConfig is! OneSignalProviderConfig) {
      _log.severe(
        'Invalid provider config type: ${providerConfig.runtimeType}. '
        'Expected OneSignalProviderConfig.',
      );
      throw const OperationFailedException(
        'Internal configuration error for OneSignal push notification client.',
      );
    }

    final appId = providerConfig.appId;
    // The REST API key is expected to be set in the HttpClient's AuthInterceptor.
    const url = 'notifications'; // Relative to the base URL

    _log.info(
      'Sending OneSignal notification to token starting with '
      '"${deviceToken.substring(0, 10)}..." for app ID "$appId".',
    );

    // Construct the OneSignal API request body.
    final requestBody = {
      'app_id': appId,
      'include_player_ids': [deviceToken],
      'headings': {'en': payload.title},
      'contents': {'en': payload.body},
      if (payload.imageUrl != null) 'big_picture': payload.imageUrl,
      'data': payload.data,
    };

    try {
      await _httpClient.post(url, data: requestBody);
      _log.info(
        'Successfully sent OneSignal notification for app ID "$appId".',
      );
    } on HttpException catch (e) {
      _log.severe('HTTP error sending OneSignal notification: ${e.message}', e);
      rethrow;
    }
  }
}
