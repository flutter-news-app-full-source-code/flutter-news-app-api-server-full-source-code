import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';

/// {@template sns_message_handler}
/// A utility class for handling Amazon SNS message lifecycle events.
///
/// This class abstracts the protocol-specific interactions required by SNS,
/// such as confirming subscriptions by visiting the `SubscribeURL`.
/// {@endtemplate}
class SnsMessageHandler {
  /// {@macro sns_message_handler}
  SnsMessageHandler({
    required HttpClient httpClient,
    required Logger log,
  }) : _httpClient = httpClient,
       _log = log;

  final HttpClient _httpClient;
  final Logger _log;

  /// Confirms an SNS subscription by visiting the provided [subscribeUrl].
  ///
  /// This is required to complete the handshake when a new HTTP/HTTPS
  /// subscription is created in AWS SNS.
  Future<void> confirmSubscription(String subscribeUrl) async {
    _log.info('Attempting to confirm SNS subscription...');
    try {
      // The SubscribeURL is a full URL provided by AWS.
      // We perform a GET request to confirm.
      await _httpClient.get<dynamic>(subscribeUrl);
      _log.info('Successfully confirmed SNS subscription.');
    } catch (e, s) {
      _log.severe('Failed to confirm SNS subscription.', e, s);
      // We rethrow because if confirmation fails, the system is misconfigured.
      rethrow;
    }
  }
}
