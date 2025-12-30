import 'package:flutter_news_app_api_server_full_source_code/src/clients/email/email.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  group('EmailLoggingClient', () {
    late Logger logger;
    late EmailLoggingClient client;

    setUp(() {
      logger = MockLogger();
      client = EmailLoggingClient(log: logger);
    });

    test('sendTransactionalEmail logs email details correctly', () async {
      const senderEmail = 'sender@example.com';
      const recipientEmail = 'recipient@example.com';
      const subject = 'Test Subject';
      const templateId = 'template-id';
      const templateData = {'otp': '123456'};

      await client.sendTransactionalEmail(
        senderEmail: senderEmail,
        recipientEmail: recipientEmail,
        subject: subject,
        templateId: templateId,
        templateData: templateData,
      );

      // Verify that log.info was called with a message containing all details
      verify(() {
        logger.info(
          any(
            that: allOf(
              contains('EMAIL LOGGING CLIENT'),
              contains('To:       $recipientEmail'),
              contains('From:     $senderEmail'),
              contains('Subject:  $subject'),
              contains('Template: $templateId'),
              contains('Data:     $templateData'),
            ),
          ),
        );
      }).called(1);
    });
  });
}
