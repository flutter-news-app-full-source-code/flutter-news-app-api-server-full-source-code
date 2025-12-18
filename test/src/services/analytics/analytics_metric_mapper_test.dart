import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/analytics/analytics.dart';
import 'package:test/test.dart';

void main() {
  group('AnalyticsMetricMapper', () {
    late AnalyticsMetricMapper mapper;

    setUp(() {
      mapper = AnalyticsMetricMapper();
    });

    test('getKpiQuery returns a query for every KpiCardId', () {
      for (final kpiId in KpiCardId.values) {
        final query = mapper.getKpiQuery(kpiId);
        expect(
          query,
          isNotNull,
          reason: 'KPI query for ${kpiId.name} should not be null.',
        );
        expect(
          query,
          isA<MetricQuery>(),
          reason: 'KPI query for ${kpiId.name} should be a MetricQuery.',
        );
      }
    });

    test('getChartQuery returns a query for every ChartCardId', () {
      for (final chartId in ChartCardId.values) {
        final query = mapper.getChartQuery(chartId);
        expect(
          query,
          isNotNull,
          reason: 'Chart query for ${chartId.name} should not be null.',
        );
      }
    });

    test('getRankedListQuery returns a query for every RankedListCardId', () {
      for (final rankedListId in RankedListCardId.values) {
        final query = mapper.getRankedListQuery(rankedListId);
        expect(
          query,
          isNotNull,
          reason:
              'Ranked list query for ${rankedListId.name} should not be null.',
        );
      }
    });
  });
}
