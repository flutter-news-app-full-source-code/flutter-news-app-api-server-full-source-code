import 'package:flutter_news_app_api_server_full_source_code/src/models/email/onesignal_request.dart';
import 'package:test/test.dart';

void main() {
  group('OneSignalEmailRequest', () {
    test('supports value equality', () {
      final request1 = OneSignalEmailRequest(
        appId: 'app-id',
        templateId: 'template-id',
        includeEmailTokens: const ['test@example.com'],
        emailSubject: 'Subject',
        customData: const {},
      );
      final request2 = OneSignalEmailRequest(
        appId: 'app-id',
        templateId: 'template-id',
        includeEmailTokens: const ['test@example.com'],
        emailSubject: 'Subject',
        customData: const {},
      );
      expect(request1, equals(request2));
    });

    test('toJson returns correct map', () {
      final request = OneSignalEmailRequest(
        appId: 'app-id',
        templateId: 'template-id',
        includeEmailTokens: const ['recipient@example.com'],
        emailSubject: 'Test Subject',
        customData: const {'key': 'value'},
      );

      final json = request.toJson();

      expect(json, {
        'app_id': 'app-id',
        'template_id': 'template-id',
        'include_email_tokens': ['recipient@example.com'],
        'email_subject': 'Test Subject',
        'custom_data': {'key': 'value'},
      });
    });
  });
}
