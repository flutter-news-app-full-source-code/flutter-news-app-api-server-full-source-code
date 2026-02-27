import 'package:flutter_news_app_backend_api_full_source_code/src/models/analytics/analytics.dart';
import 'package:test/test.dart';

void main() {
  group('Mixpanel Response Models', () {
    group('MixpanelResponse<MixpanelSegmentationData>', () {
      test('fromJson correctly parses a valid JSON payload', () {
        final json = {
          'data': {
            'series': ['2024-01-01', '2024-01-02'],
            'values': {
              'contentViewed': [100, 150],
            },
          },
        };

        final response = MixpanelResponse.fromJson(
          json,
          (jsonData) => MixpanelSegmentationData.fromJson(
            jsonData as Map<String, dynamic>,
          ),
        );

        expect(response.data, isA<MixpanelSegmentationData>());
        expect(response.data.series, equals(['2024-01-01', '2024-01-02']));
        expect(response.data.values, containsPair('contentViewed', [100, 150]));
      });

      test('throws CheckedFromJsonException for malformed data', () {
        final json = {
          'data': {
            'series': ['2024-01-01'],
            // Missing 'values' field
          },
        };

        expect(
          () => MixpanelResponse.fromJson(
            json,
            (jsonData) => MixpanelSegmentationData.fromJson(
              jsonData as Map<String, dynamic>,
            ),
          ),
          throwsA(isA<Exception>()), // More specific exception if possible
        );
      });
    });
  });
}
