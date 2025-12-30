import 'package:flutter_news_app_api_server_full_source_code/src/models/email/sendgrid_request.dart';
import 'package:test/test.dart';

void main() {
  group('SendGridRequest', () {
    test('supports value equality', () {
      const request1 = SendGridRequest(
        personalizations: [],
        from: SendGridFrom(email: 'test@example.com'),
        templateId: 'template-id',
      );
      const request2 = SendGridRequest(
        personalizations: [],
        from: SendGridFrom(email: 'test@example.com'),
        templateId: 'template-id',
      );
      expect(request1, equals(request2));
    });

    test('toJson returns correct map', () {
      const request = SendGridRequest(
        personalizations: [
          SendGridPersonalization(
            to: [SendGridTo(email: 'recipient@example.com')],
            subject: 'Test Subject',
            dynamicTemplateData: {'key': 'value'},
          ),
        ],
        from: SendGridFrom(email: 'sender@example.com'),
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
