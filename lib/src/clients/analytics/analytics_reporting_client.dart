import 'package:core/core.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/models.dart';

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
  /// - [query]: The structured query object defining what to fetch.
  /// - [startDate]: The start date for the time range.
  /// - [endDate]: The end date for the time range.
  ///
  /// Returns a list of [DataPoint]s representing the metric's value over time.
  Future<List<DataPoint>> getTimeSeries(
    MetricQuery query,
    DateTime startDate,
    DateTime endDate,
  );

  /// Fetches a single metric value for a given time range.
  ///
  /// - [query]: The structured metric query object defining what to fetch.
  /// - [startDate]: The start date for the time range.
  /// - [endDate]: The end date for the time range.
  ///
  /// Returns the total value of the metric as a [num].
  Future<num> getMetricTotal(
    MetricQuery query,
    DateTime startDate,
    DateTime endDate,
  );

  /// Fetches a ranked list of items based on a metric.
  Future<List<RankedListItem>> getRankedList(
    RankedListQuery query,
    DateTime startDate,
    DateTime endDate,
  );

  /// Fetches time-series data for multiple date ranges in a single batch.
  ///
  /// - [query]: The structured query object defining what to fetch.
  /// - [ranges]: A list of date ranges to fetch data for.
  ///
  /// Returns a map where keys are the requested [GARequestDateRange] objects
  /// and values are the corresponding lists of [DataPoint]s.
  Future<Map<GARequestDateRange, List<DataPoint>>> getTimeSeriesBatch(
    MetricQuery query,
    List<GARequestDateRange> ranges,
  );

  /// Fetches single metric totals for multiple date ranges in a single batch.
  ///
  /// - [query]: The structured metric query object defining what to fetch.
  /// - [ranges]: A list of date ranges to fetch data for.
  ///
  /// Returns a map where keys are the requested [GARequestDateRange] objects
  /// and values are the corresponding total metric values.
  Future<Map<GARequestDateRange, num>> getMetricTotalsBatch(
    MetricQuery query,
    List<GARequestDateRange> ranges,
  );
}
