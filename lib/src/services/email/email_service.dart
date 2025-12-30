// New file: lib/src/services/email/email_service.dart
import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/email/email_client.dart';

/// {@template email_service}
/// A service that handles email sending operations.
///
/// This service acts as an abstraction layer over an [EmailClient],
/// providing a consistent interface for business logic to send emails,
/// such as One-Time Passwords (OTPs).
/// {@endtemplate}
class EmailService {
  /// {@macro email_service}
  ///
  /// Requires an instance of [EmailClient] to handle the actual
  /// email sending operations.
  const EmailService({required EmailClient emailClient})
      : _emailClient = emailClient;

  final EmailClient _emailClient;

  /// Sends a One-Time Password (OTP) email by calling the underlying client.
  ///
  /// This method abstracts the specific details of sending an OTP email. It
  /// constructs the required `templateData` and calls the generic
  /// `sendTransactionalEmail` method on the injected [EmailClient].
  ///
  /// - [senderEmail]: The email address of the sender.
  /// - [recipientEmail]: The email address of the recipient.
  /// - [subject]: The subject line of the email.
  /// - [otpCode]: The One-Time Password to be sent.
  /// - [templateId]: The ID of the transactional email template to use.
  ///
  /// Throws [HttpException] subtypes on failure, as propagated from the
  /// client.
  Future<void> sendOtpEmail({
    required String senderEmail,
    required String recipientEmail,
    required String subject,
    required String otpCode,
    required String templateId,
  }) async {
    try {
      await _emailClient.sendTransactionalEmail(
        senderEmail: senderEmail,
        recipientEmail: recipientEmail,
        subject: subject,
        templateId: templateId,
        templateData: {'otp_code': otpCode},
      );
    } on HttpException {
      rethrow;
    }
  }
}
