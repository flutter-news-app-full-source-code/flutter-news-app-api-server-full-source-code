import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart';

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
    AnalyticsQuery query,
    DateTime startDate,
    DateTime endDate,
  );

  /// Fetches a single metric value for a given time range.
  ///
  /// - [query]: The structured query object defining what to fetch.
  /// - [startDate]: The start date for the time range.
  /// - [endDate]: The end date for the time range.
  ///
  /// Returns the total value of the metric as a [num].
  Future<num> getMetricTotal(
    AnalyticsQuery query,
    DateTime startDate,
    DateTime endDate,
  );

  /// Fetches a ranked list of items based on a metric.
  Future<List<RankedListItem>> getRankedList(
    RankedListQuery query,
    DateTime startDate,
    DateTime endDate,
  );
}
