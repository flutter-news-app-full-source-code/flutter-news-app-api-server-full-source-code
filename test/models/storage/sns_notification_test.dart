import 'package:flutter_news_app_api_server_full_source_code/src/models/storage/sns_notification.dart';
import 'package:test/test.dart';

void main() {
  group('SnsNotification', () {
    test('parses Notification payload correctly', () {
      final json = {
        'Type': 'Notification',
        'MessageId': '22b80b92-fdea-4c2c-8f9d-bdfb0c7bf324',
        'TopicArn': 'arn:aws:sns:us-west-2:123456789012:MyTopic',
        'Subject': 'My First Message',
        'Message': 'Hello world!',
        'Timestamp': '2012-05-02T00:54:06.655Z',
        'SignatureVersion': '1',
        'Signature': 'EXAMPLE_SIGNATURE',
        'SigningCertURL': 'EXAMPLE_URL',
        'UnsubscribeURL': 'EXAMPLE_URL',
      };

      final sns = SnsNotification.fromJson(json);

      expect(sns.type, 'Notification');
      expect(sns.messageId, '22b80b92-fdea-4c2c-8f9d-bdfb0c7bf324');
      expect(sns.topicArn, 'arn:aws:sns:us-west-2:123456789012:MyTopic');
      expect(sns.message, 'Hello world!');
      expect(sns.timestamp, DateTime.utc(2012, 5, 2, 0, 54, 6, 655));
    });

    test('parses SubscriptionConfirmation payload correctly', () {
      final json = {
        'Type': 'SubscriptionConfirmation',
        'MessageId': '165545c9-2a5c-472c-8df2-7ff2be2b3b1b',
        'Token': '2336412f37...',
        'TopicArn': 'arn:aws:sns:us-west-2:123456789012:MyTopic',
        'Message':
            'You have chosen to subscribe to the topic arn:aws:sns:us-west-2:123456789012:MyTopic...',
        'SubscribeURL':
            'https://sns.us-west-2.amazonaws.com/?Action=ConfirmSubscription&TopicArn=arn:aws:sns:us-west-2:123456789012:MyTopic&Token=2336412f37...',
        'Timestamp': '2012-04-26T20:45:04.751Z',
      };

      final sns = SnsNotification.fromJson(json);

      expect(sns.type, 'SubscriptionConfirmation');
      expect(sns.subscribeUrl, contains('ConfirmSubscription'));
    });
  });
}
