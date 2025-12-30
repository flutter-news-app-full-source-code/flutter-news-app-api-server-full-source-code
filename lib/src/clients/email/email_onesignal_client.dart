// New file: lib/src/services/email/email_onesignal_client.dart
import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/email/email_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/email/onesignal_request.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';

/// {@template email_onesignal_client}
/// A client for sending emails using the OneSignal API.
///
/// This class implements the [EmailClient] interface and uses an
/// [HttpClient] to communicate with the OneSignal API.
/// {@endtemplate}
class EmailOneSignalClient implements EmailClient {
  /// {@macro email_onesignal_client}
  const EmailOneSignalClient({
    required this.appId,
    required HttpClient httpClient,
    required Logger log,
  }) : _httpClient = httpClient,
       _log = log;

  /// The OneSignal App ID.
  final String appId;
  final HttpClient _httpClient;
  final Logger _log;

  static const String _notificationsPath = 'notifications';

  @override
  Future<void> sendTransactionalEmail({
    required String senderEmail,
    required String recipientEmail,
    required String subject,
    required String templateId,
    required Map<String, dynamic> templateData,
  }) async {
    _log.info(
      'Attempting to send email to $recipientEmail with template $templateId via OneSignal',
    );

    // Construct the strongly-typed payload.
    final request = OneSignalEmailRequest(
      appId: appId,
      templateId: templateId,
      includeEmailTokens: [recipientEmail],
      emailSubject: subject,
      customData: templateData,
    );

    try {
      await _httpClient.post<void>(_notificationsPath, data: request.toJson());
      _log.info(
        'Successfully requested email send to $recipientEmail via OneSignal',
      );
    } on HttpException {
      rethrow;
    } catch (e, s) {
      _log.severe(
        'An unexpected error occurred while sending email via OneSignal.',
        e,
        s,
      );
      throw OperationFailedException('An unexpected error occurred: $e');
    }
  }
}
