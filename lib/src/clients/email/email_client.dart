import 'package:core/core.dart';

/// {@template email_client}
/// Defines the interface for sending emails within the backend system.
///
/// Concrete implementations (e.g., using specific email providers like
/// SendGrid, OneSignal, or AWS SES) will handle the actual email dispatch.
/// {@endtemplate}
abstract class EmailClient {
  /// {@macro email_client}
  const EmailClient();

  /// Sends a transactional email using a pre-defined template.
  ///
  /// This method is designed to be provider-agnostic, relying on the email
  /// service to manage the actual email content via templates.
  ///
  /// - [senderEmail]: The email address of the sender.
  /// - [recipientEmail]: The email address of the recipient.
  /// - [subject]: The subject line of the email.
  /// - [templateId]: The unique identifier for the dynamic template stored in
  ///   the email service provider.
  /// - [templateData]: A map of dynamic data to be merged into the template.
  ///   For example: `{'otpCode': '123456', 'username': 'Alex'}`.
  ///
  /// Throws [HttpException] or its subtypes on failure.
  Future<void> sendTransactionalEmail({
    required String senderEmail,
    required String recipientEmail,
    required String subject,
    required String templateId,
    required Map<String, dynamic> templateData,
  });
}
