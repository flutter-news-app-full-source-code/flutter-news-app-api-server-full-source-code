import 'package:flutter_news_app_backend_api_full_source_code/src/models/analytics/analytics.dart';
import 'package:test/test.dart';

void main() {
  group('Google Analytics Request Models', () {
    group('RunReportRequest', () {
      test('toJson produces correct map structure', () {
        const request = RunReportRequest(
          dateRanges: [
            GARequestDateRange(startDate: '2024-01-01', endDate: '2024-01-31'),
          ],
          dimensions: [GARequestDimension(name: 'date')],
          metrics: [GARequestMetric(name: 'activeUsers')],
          dimensionFilter: GARequestFilterExpression(
            filter: GARequestFilter(
              fieldName: 'eventName',
              stringFilter: GARequestStringFilter(value: 'contentViewed'),
            ),
          ),
          limit: 100,
        );

        final json = request.toJson();

        final expectedJson = {
          'dateRanges': [
            {'startDate': '2024-01-01', 'endDate': '2024-01-31'},
          ],
          'dimensions': [
            {'name': 'date'},
          ],
          'metrics': [
            {'name': 'activeUsers'},
          ],
          'dimensionFilter': {
            'filter': {
              'fieldName': 'eventName',
              'stringFilter': {'value': 'contentViewed'},
            },
          },
          'limit': 100,
        };

        expect(json, equals(expectedJson));
      });

      test('toJson omits null fields', () {
        const request = RunReportRequest(
          dateRanges: [
            GARequestDateRange(startDate: '2024-01-01', endDate: '2024-01-31'),
          ],
        );
        final json = request.toJson();
        expect(json.containsKey('dimensions'), isFalse);
        expect(json.containsKey('metrics'), isFalse);
      });
    });

    group('GARequestDateRange', () {
      test('from constructor formats dates correctly', () {
        final range = GARequestDateRange.from(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 31),
        );
        expect(range.startDate, '2024-01-01');
        expect(range.endDate, '2024-01-31');
      });
    });
  });
}
