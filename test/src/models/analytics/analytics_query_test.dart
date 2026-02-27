import 'package:core/core.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/analytics/analytics.dart';
import 'package:test/test.dart';

void main() {
  group('AnalyticsQuery', () {
    group('EventCountQuery', () {
      test('supports value equality', () {
        const query1 = EventCountQuery(event: AnalyticsEvent.contentViewed);
        const query2 = EventCountQuery(event: AnalyticsEvent.contentViewed);
        const query3 = EventCountQuery(event: AnalyticsEvent.userLogin);
        expect(query1, equals(query2));
        expect(query1, isNot(equals(query3)));
      });
    });

    group('StandardMetricQuery', () {
      test('supports value equality', () {
        const query1 = StandardMetricQuery(metric: 'activeUsers');
        const query2 = StandardMetricQuery(metric: 'activeUsers');
        const query3 = StandardMetricQuery(metric: 'totalUsers');
        expect(query1, equals(query2));
        expect(query1, isNot(equals(query3)));
      });
    });

    group('RankedListQuery', () {
      test('supports value equality', () {
        const query1 = RankedListQuery(
          event: AnalyticsEvent.contentViewed,
          dimension: 'contentId',
        );
        const query2 = RankedListQuery(
          event: AnalyticsEvent.contentViewed,
          dimension: 'contentId',
        );
        expect(query1, equals(query2));
      });
    });
  });
}
