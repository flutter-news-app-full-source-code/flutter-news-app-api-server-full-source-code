import 'package:core/core.dart';

/// A record to hold provider-specific metric and dimension names.
typedef ProviderMetrics = ({String metric, String? dimension});

/// {@template analytics_metric_mapper}
/// A class that maps internal analytics card IDs to provider-specific metrics.
///
/// This centralizes the "dictionary" of what to query for each card,
/// decoupling the sync service from the implementation details of each
/// analytics provider.
/// {@endtemplate}
class AnalyticsMetricMapper {
  /// Returns the provider-specific metric and dimension for a given KPI card.
  ProviderMetrics getKpiMetrics(KpiCardId kpiId, AnalyticsProvider provider) {
    switch (provider) {
      case AnalyticsProvider.firebase:
        return _firebaseKpiMappings[kpiId]!;
      case AnalyticsProvider.mixpanel:
        return _mixpanelKpiMappings[kpiId]!;
      case AnalyticsProvider.demo:
        throw UnimplementedError('Demo provider does not have metrics.');
    }
  }

  /// Returns the provider-specific metric and dimension for a given chart card.
  ProviderMetrics getChartMetrics(
    ChartCardId chartId,
    AnalyticsProvider provider,
  ) {
    switch (provider) {
      case AnalyticsProvider.firebase:
        return _firebaseChartMappings[chartId]!;
      case AnalyticsProvider.mixpanel:
        return _mixpanelChartMappings[chartId]!;
      case AnalyticsProvider.demo:
        throw UnimplementedError('Demo provider does not have metrics.');
    }
  }

  /// Returns the provider-specific metric and dimension for a ranked list.
  ProviderMetrics getRankedListMetrics(
    RankedListCardId rankedListId,
    AnalyticsProvider provider,
  ) {
    switch (provider) {
      case AnalyticsProvider.firebase:
        return _firebaseRankedListMappings[rankedListId]!;
      case AnalyticsProvider.mixpanel:
        return _mixpanelRankedListMappings[rankedListId]!;
      case AnalyticsProvider.demo:
        throw UnimplementedError('Demo provider does not have metrics.');
    }
  }

  // In a real-world scenario, these mappings would be comprehensive.
  // For this implementation, we will map a few key examples.
  // The service will gracefully handle missing mappings.

  static final Map<KpiCardId, ProviderMetrics> _firebaseKpiMappings = {
    KpiCardId.users_total_registered: (metric: 'eventCount', dimension: null),
    KpiCardId.users_active_users: (metric: 'activeUsers', dimension: null),
    KpiCardId.content_headlines_total_views:
        (metric: 'eventCount', dimension: null),
    // ... other mappings
  };

  static final Map<KpiCardId, ProviderMetrics> _mixpanelKpiMappings = {
    KpiCardId.users_total_registered:
        (metric: AnalyticsEvent.userRegistered.name, dimension: null),
    KpiCardId.users_active_users: (metric: '\$active', dimension: null),
    KpiCardId.content_headlines_total_views:
        (metric: AnalyticsEvent.contentViewed.name, dimension: null),
    // ... other mappings
  };

  static final Map<ChartCardId, ProviderMetrics> _firebaseChartMappings = {
    ChartCardId.users_registrations_over_time:
        (metric: 'eventCount', dimension: 'date'),
    ChartCardId.users_active_users_over_time:
        (metric: 'activeUsers', dimension: 'date'),
    // ... other mappings
  };

  static final Map<ChartCardId, ProviderMetrics> _mixpanelChartMappings = {
    ChartCardId.users_registrations_over_time:
        (metric: AnalyticsEvent.userRegistered.name, dimension: 'date'),
    ChartCardId.users_active_users_over_time:
        (metric: '\$active', dimension: 'date'),
    // ... other mappings
  };

  static final Map<RankedListCardId, ProviderMetrics>
      _firebaseRankedListMappings = {
    RankedListCardId.overview_headlines_most_viewed:
        (metric: 'eventCount', dimension: 'customEvent:contentId'),
  };

  static final Map<RankedListCardId, ProviderMetrics>
      _mixpanelRankedListMappings = {
    RankedListCardId.overview_headlines_most_viewed:
        (metric: AnalyticsEvent.contentViewed.name, dimension: 'contentId'),
  };
}