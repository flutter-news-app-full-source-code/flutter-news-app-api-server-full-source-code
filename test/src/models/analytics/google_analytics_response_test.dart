import 'package:flutter_news_app_api_server_full_source_code/src/models/analytics/analytics.dart';
import 'package:test/test.dart';

void main() {
  group('Google Analytics Response Models', () {
    group('RunReportResponse', () {
      test('fromJson correctly parses a valid JSON payload', () {
        final json = {
          'rows': [
            {
              'dimensionValues': [
                {'value': '20240101'},
              ],
              'metricValues': [
                {'value': '123'},
              ],
            },
            {
              'dimensionValues': [
                {'value': '20240102'},
              ],
              'metricValues': [
                {'value': '456'},
              ],
            },
          ],
        };

        final response = RunReportResponse.fromJson(json);

        expect(response.rows, isNotNull);
        expect(response.rows!.length, 2);

        final firstRow = response.rows!.first;
        expect(firstRow.dimensionValues.first.value, '20240101');
        expect(firstRow.metricValues.first.value, '123');
      });

      test('fromJson handles null rows gracefully', () {
        final json = <String, dynamic>{}; // Empty JSON
        final response = RunReportResponse.fromJson(json);
        expect(response.rows, isNull);
      });
    });
  });
}
