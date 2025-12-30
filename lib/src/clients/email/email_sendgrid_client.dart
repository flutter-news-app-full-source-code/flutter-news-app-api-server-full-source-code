// ignore_for_file: lines_longer_than_80_chars

import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/email/email_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/email/sendgrid_request.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';

/// {@template email_sendgrid_client}
/// A client for sending emails using the SendGrid API.
///
/// This class implements the [EmailClient] interface and uses an
/// [HttpClient] to communicate with the SendGrid v3 API.
/// {@endtemplate}
class EmailSendGridClient implements EmailClient {
  /// {@macro email_sendgrid_client}
  ///
  /// Requires a pre-configured [HttpClient] instance that includes the
  /// SendGrid API base URL ('https://api.sendgrid.com/v3') and an
  /// authentication interceptor to provide the SendGrid API key as a
  /// Bearer token.
  const EmailSendGridClient({
    required HttpClient httpClient,
    required Logger log,
  }) : _httpClient = httpClient,
       _log = log;

  final HttpClient _httpClient;
  final Logger _log;

  static const String _sendPath = '/mail/send';

  @override
  Future<void> sendTransactionalEmail({
    required String senderEmail,
    required String recipientEmail,
    required String subject,
    required String templateId,
    required Map<String, dynamic> templateData,
  }) async {
    _log.info(
      'Attempting to send email to $recipientEmail with template $templateId via SendGrid',
    );

    // Construct the strongly-typed payload.
    final request = SendGridRequest(
      personalizations: [
        SendGridPersonalization(
          to: [SendGridTo(email: recipientEmail)],
          subject: subject,
          dynamicTemplateData: templateData,
        ),
      ],
      from: SendGridFrom(email: senderEmail),
      templateId: templateId,
    );

    try {
      // The HttpClient's post method will handle the request and its
      // ErrorInterceptor will map DioExceptions to HttpExceptions.
      await _httpClient.post<void>(_sendPath, data: request.toJson());
      _log.info(
        'Successfully requested email send to $recipientEmail via SendGrid',
      );
    } on HttpException {
      // Re-throw the already mapped exception for the service layer to handle.
      rethrow;
    } catch (e, s) {
      // Catch any other unexpected errors.
      _log.severe(
        'An unexpected error occurred while sending email via SendGrid.',
        e,
        s,
      );
      throw OperationFailedException('An unexpected error occurred: $e');
    }
  }
}
