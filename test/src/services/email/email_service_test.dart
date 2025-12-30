import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/email/email_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/email/email_service.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockEmailClient extends Mock implements EmailClient {}

class MockLogger extends Mock implements Logger {}

void main() {
  group('EmailService', () {
    late EmailClient emailClient;
    late Logger logger;
    late EmailService service;

    setUp(() {
      emailClient = MockEmailClient();
      logger = MockLogger();
      service = EmailService(emailClient: emailClient, log: logger);
    });

    test('sendOtpEmail calls client with correct parameters', () async {
      when(
        () => emailClient.sendTransactionalEmail(
          senderEmail: any(named: 'senderEmail'),
          recipientEmail: any(named: 'recipientEmail'),
          subject: any(named: 'subject'),
          templateId: any(named: 'templateId'),
          templateData: any(named: 'templateData'),
        ),
      ).thenAnswer((_) async {});

      await service.sendOtpEmail(
        senderEmail: 'sender@example.com',
        recipientEmail: 'recipient@example.com',
        subject: 'OTP Code',
        otpCode: '123456',
        templateId: 'template-id',
      );

      verify(
        () => emailClient.sendTransactionalEmail(
          senderEmail: 'sender@example.com',
          recipientEmail: 'recipient@example.com',
          subject: 'OTP Code',
          templateId: 'template-id',
          templateData: {'otp_code': '123456'},
        ),
      ).called(1);
    });

    test('sendOtpEmail rethrows HttpException', () async {
      when(
        () => emailClient.sendTransactionalEmail(
          senderEmail: any(named: 'senderEmail'),
          recipientEmail: any(named: 'recipientEmail'),
          subject: any(named: 'subject'),
          templateId: any(named: 'templateId'),
          templateData: any(named: 'templateData'),
        ),
      ).thenThrow(const NetworkException());

      expect(
        () => service.sendOtpEmail(
          senderEmail: 'sender@example.com',
          recipientEmail: 'recipient@example.com',
          subject: 'OTP Code',
          otpCode: '123456',
          templateId: 'template-id',
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('sendOtpEmail wraps unexpected exceptions', () async {
      when(
        () => emailClient.sendTransactionalEmail(
          senderEmail: any(named: 'senderEmail'),
          recipientEmail: any(named: 'recipientEmail'),
          subject: any(named: 'subject'),
          templateId: any(named: 'templateId'),
          templateData: any(named: 'templateData'),
        ),
      ).thenThrow(Exception('Unexpected'));

      expect(
        () => service.sendOtpEmail(
          senderEmail: 'sender@example.com',
          recipientEmail: 'recipient@example.com',
          subject: 'OTP Code',
          otpCode: '123456',
          templateId: 'template-id',
        ),
        throwsA(isA<OperationFailedException>()),
      );
    });
  });
}
