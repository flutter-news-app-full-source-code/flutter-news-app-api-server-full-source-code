import 'package:core/core.dart';

/// A sealed class representing a structured, provider-agnostic analytics query.
///
/// This replaces the fragile pattern of passing primitive strings for metrics
/// and dimensions, centralizing query definitions into type-safe objects.
sealed class AnalyticsQuery {
  /// {@macro analytics_query}
  const AnalyticsQuery();
}

/// A sealed class for queries that return a numeric metric value, such as
/// a total count or a time series.
sealed class MetricQuery extends AnalyticsQuery {
  /// {@macro metric_query}
  const MetricQuery();
}

/// A query for a simple event count.
///
/// This is used when the metric is the count of a specific [AnalyticsEvent].
class EventCountQuery extends MetricQuery {
  /// {@macro event_count_query}
  const EventCountQuery({required this.event});

  /// The core, type-safe event from the shared [AnalyticsEvent] enum.
  final AnalyticsEvent event;
}

/// A query for a standard, provider-defined metric (e.g., 'activeUsers').
///
/// This is used for metrics that have a built-in name in the provider's API.
class StandardMetricQuery extends MetricQuery {
  /// {@macro standard_metric_query}
  const StandardMetricQuery({required this.metric});

  /// The provider-specific name for a standard metric.
  final String metric;
}

/// A query for a ranked list of items.
///
/// This is used to get a "Top N" list, such as most viewed headlines.
class RankedListQuery extends AnalyticsQuery {
  /// {@macro ranked_list_query}
  const RankedListQuery({
    required this.event,
    required this.dimension,
    this.limit = 10,
  });

  /// The event to count for ranking (e.g., `contentViewed`).
  final AnalyticsEvent event;

  /// The property/dimension to group by (e.g., `contentId`).
  final String dimension;

  /// The number of items to return in the ranked list.
  final int limit;
}
