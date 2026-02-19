import 'package:flutter_news_app_api_server_full_source_code/src/models/storage/s3_notification.dart';
import 'package:test/test.dart';

void main() {
  group('S3Notification', () {
    test('parses standard S3 event JSON correctly', () {
      final json = {
        'Records': [
          {
            'eventVersion': '2.1',
            'eventSource': 'aws:s3',
            'awsRegion': 'us-east-1',
            'eventTime': '2024-01-01T12:00:00.000Z',
            'eventName': 'ObjectCreated:Put',
            'userIdentity': {'principalId': 'AWS:AID...'},
            'requestParameters': {'sourceIPAddress': '1.2.3.4'},
            'responseElements': {
              'x-amz-request-id': 'C3D...',
              'x-amz-id-2': '...',
            },
            's3': {
              's3SchemaVersion': '1.0',
              'configurationId': 'testConfigRule',
              'bucket': {
                'name': 'my-bucket',
                'ownerIdentity': {'principalId': 'A3...'},
                'arn': 'arn:aws:s3:::my-bucket',
              },
              'object': {
                'key': 'uploads%2Fimage.jpg',
                'size': 1024,
                'eTag': 'd41d8cd98f00b204e9800998ecf8427e',
                'sequencer': '0055AED6DCD90281E5',
              },
            },
          },
        ],
      };

      final notification = S3Notification.fromJson(json);

      expect(notification.records.length, 1);
      final record = notification.records.first;

      expect(record.eventName, 'ObjectCreated:Put');
      expect(record.eventSource, 'aws:s3');
      expect(record.awsRegion, 'us-east-1');
      expect(record.eventTime, DateTime.utc(2024, 1, 1, 12, 0, 0));

      expect(record.s3.object.key, 'uploads%2Fimage.jpg');
      expect(record.s3.object.decodedKey, 'uploads/image.jpg');
    });

    test('handles empty records list', () {
      final json = {'Records': []};
      final notification = S3Notification.fromJson(json);
      expect(notification.records, isEmpty);
    });

    // Note: We rely on checked: true in JsonSerializable to throw FormatException
    // for missing required fields, which is implicitly tested by the framework.
  });
}
