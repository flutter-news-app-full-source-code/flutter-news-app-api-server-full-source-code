import 'package:flutter_news_app_api_server_full_source_code/src/models/email/sendgrid_request.dart';
import 'package:test/test.dart';

void main() {
  group('SendGridRequest', () {
    test('supports value equality', () {
      final request1 = SendGridRequest(
        personalizations: const [],
        from: const SendGridFrom(email: 'test@example.com'),
        templateId: 'template-id',
      );
      final request2 = SendGridRequest(
        personalizations: const [],
        from: const SendGridFrom(email: 'test@example.com'),
        templateId: 'template-id',
      );
      expect(request1, equals(request2));
    });

    test('toJson returns correct map', () {
      final request = SendGridRequest(
        personalizations: [
          SendGridPersonalization(
            to: [const SendGridTo(email: 'recipient@example.com')],
            subject: 'Test Subject',
            dynamicTemplateData: const {'key': 'value'},
          ),
        ],
        from: const SendGridFrom(email: 'sender@example.com'),
        templateId: 'template-id',
      );

      final json = request.toJson();

      expect(json, {
        'personalizations': [
          {
            'to': [
              {'email': 'recipient@example.com'},
            ],
            'subject': 'Test Subject',
            'dynamic_template_data': {'key': 'value'},
          },
        ],
        'from': {'email': 'sender@example.com'},
        'template_id': 'template-id',
      });
    });
  });
}
