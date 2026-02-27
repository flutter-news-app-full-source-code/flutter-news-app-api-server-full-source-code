import 'package:flutter_news_app_backend_api_full_source_code/src/models/analytics/analytics.dart';
import 'package:test/test.dart';

void main() {
  group('Mixpanel Request Models', () {
    group('MixpanelSegmentationRequest', () {
      test('toJson produces correct map structure', () {
        const request = MixpanelSegmentationRequest(
          projectId: 'proj1',
          event: 'testEvent',
          fromDate: '2024-01-01',
          toDate: '2024-01-31',
          unit: MixpanelTimeUnit.week,
        );

        final json = request.toJson();

        final expectedJson = {
          'project_id': 'proj1',
          'event': 'testEvent',
          'from_date': '2024-01-01',
          'to_date': '2024-01-31',
          'unit': 'week',
        };

        expect(json, equals(expectedJson));
      });
    });

    group('MixpanelTopEventsRequest', () {
      test('toJson produces correct map structure', () {
        const request = MixpanelTopEventsRequest(
          projectId: 'proj2',
          event: 'topEvent',
          name: 'contentId',
          fromDate: '2024-02-01',
          toDate: '2024-02-28',
          limit: 5,
        );

        final json = request.toJson();

        final expectedJson = {
          'project_id': 'proj2',
          'event': 'topEvent',
          'name': 'contentId',
          'from_date': '2024-02-01',
          'to_date': '2024-02-28',
          'limit': 5,
        };

        expect(json, equals(expectedJson));
      });
    });
  });
}
