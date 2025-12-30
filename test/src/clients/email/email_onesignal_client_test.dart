import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/email/email_onesignal_client.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockLogger extends Mock implements Logger {}

void main() {
  group('EmailOneSignalClient', () {
    late HttpClient httpClient;
    late Logger logger;
    late EmailOneSignalClient client;

    setUp(() {
      httpClient = MockHttpClient();
      logger = MockLogger();
      client = EmailOneSignalClient(
        appId: 'app-id',
        httpClient: httpClient,
        log: logger,
      );
    });

    test('sendTransactionalEmail sends correct request', () async {
      when(
        () => httpClient.post<void>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async {});

      await client.sendTransactionalEmail(
        senderEmail: 'sender@example.com',
        recipientEmail: 'recipient@example.com',
        subject: 'Subject',
        templateId: 'template-id',
        templateData: {'otp': '1234'},
      );

      verify(
        () => httpClient.post<void>(
          'notifications',
          data: any(named: 'data', that: isA<Map<String, dynamic>>()),
        ),
      ).called(1);
    });

    test('rethrows HttpException', () async {
      when(
        () => httpClient.post<void>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenThrow(const NetworkException());

      expect(
        () => client.sendTransactionalEmail(
          senderEmail: 'sender@example.com',
          recipientEmail: 'recipient@example.com',
          subject: 'Subject',
          templateId: 'template-id',
          templateData: {},
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('wraps unexpected exceptions in OperationFailedException', () async {
      when(
        () => httpClient.post<void>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenThrow(Exception('Unexpected'));

      expect(
        () => client.sendTransactionalEmail(
          senderEmail: 'sender@example.com',
          recipientEmail: 'recipient@example.com',
          subject: 'Subject',
          templateId: 'template-id',
          templateData: {},
        ),
        throwsA(isA<OperationFailedException>()),
      );
    });
  });
}
