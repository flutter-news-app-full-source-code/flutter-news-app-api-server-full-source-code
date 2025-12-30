import 'package:flutter_news_app_api_server_full_source_code/src/clients/email/email_client.dart';
import 'package:logging/logging.dart';

/// {@template email_logging_client}
/// A development-only email client that logs email details to the console.
///
/// This client is used when the environment is explicitly configured to use
/// the 'LOGGING' email provider. It allows developers to see OTP codes and
/// other transactional messages in the server logs without needing a real
/// email infrastructure.
/// {@endtemplate}
class EmailLoggingClient implements EmailClient {
  /// {@macro email_logging_client}
  const EmailLoggingClient({required this.log});

  /// The logger used to output email details.
  final Logger log;

  @override
  Future<void> sendTransactionalEmail({
    required String senderEmail,
    required String recipientEmail,
    required String subject,
    required String templateId,
    required Map<String, dynamic> templateData,
  }) async {
    final buffer = StringBuffer()
      ..writeln('')
      ..writeln(
        '╔════════════════════════════════════════════════════════════╗',
      )
      ..writeln(
        '║              EMAIL LOGGING CLIENT (LOCAL DEV)              ║',
      )
      ..writeln(
        '╠════════════════════════════════════════════════════════════╣',
      )
      ..writeln('║ To:       $recipientEmail')
      ..writeln('║ From:     $senderEmail')
      ..writeln('║ Subject:  $subject')
      ..writeln('║ Template: $templateId')
      ..writeln('║ Data:     $templateData')
      ..writeln(
        '╚════════════════════════════════════════════════════════════╝',
      )
      ..writeln('');

    log.info(buffer.toString());
  }
}
