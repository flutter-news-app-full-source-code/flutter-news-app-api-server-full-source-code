import 'package:core/core.dart';

/// {@template analytics_reporting_client}
/// An abstract interface for a client that fetches aggregated analytics data
/// from a third-party provider.
///
/// This contract ensures that the `AnalyticsSyncService` can interact with
/// different providers (like Google Analytics or Mixpanel) in a uniform way.
/// {@endtemplate}
abstract class AnalyticsReportingClient {
  /// Fetches time-series data for a given metric.
  ///
  /// - [metricName]: The name of the metric to query (e.g., 'activeUsers').
  /// - [startDate]: The start date for the time range.
  /// - [endDate]: The end date for the time range.
  ///
  /// Returns a list of [DataPoint]s representing the metric's value over time.
  Future<List<DataPoint>> getTimeSeries(
    String metricName,
    DateTime startDate,
    DateTime endDate,
  );

  /// Fetches a single metric value for a given time range.
  ///
  /// - [metricName]: The name of the metric to query.
  /// - [startDate]: The start date for the time range.
  /// - [endDate]: The end date for the time range.
  ///
  /// Returns the total value of the metric as a [num].
  Future<num> getMetricTotal(
    String metricName,
    DateTime startDate,
    DateTime endDate,
  );

  /// Fetches a ranked list of items based on a metric.
  Future<List<RankedListItem>> getRankedList(
    String dimensionName,
    String metricName,
  );
}
