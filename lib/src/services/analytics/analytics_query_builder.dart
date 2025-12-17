import 'package:flutter_news_app_api_server_full_source_code/src/models/analytics/analytics.dart';

/// {@template analytics_query_builder}
/// A builder class responsible for creating complex MongoDB aggregation
/// pipelines for analytics queries.
///
/// This class centralizes the query logic, decoupling the
/// `AnalyticsSyncService` from the specific implementation details of
/// database aggregations.
/// {@endtemplate}
class AnalyticsQueryBuilder {
  /// Creates a MongoDB aggregation pipeline for a given database metric.
  ///
  /// Returns `null` if the metric is not a supported database query.
  List<Map<String, dynamic>>? buildPipelineForMetric(
    StandardMetricQuery query,
    DateTime startDate,
    DateTime endDate,
  ) {
    final metric = query.metric;

    switch (metric) {
      case 'database:userRoleDistribution':
        return _buildUserRoleDistributionPipeline();
      case 'database:reportsByReason':
        return _buildReportsByReasonPipeline(startDate, endDate);
      case 'database:reactionsByType':
        return _buildReactionsByTypePipeline(startDate, endDate);
      case 'database:appReviewFeedback':
        return _buildAppReviewFeedbackPipeline(startDate, endDate);
      default:
        // This case is intentionally left to return null for metrics that
        // are not categorical and are handled by other methods, like simple
        // counts.
        return null;
    }
  }

  /// Creates a pipeline for user role distribution.
  /// This is a snapshot and does not use a date filter.
  List<Map<String, dynamic>> _buildUserRoleDistributionPipeline() {
    return [
      {
        r'$group': {
          '_id': r'$appRole',
          'count': {r'$sum': 1},
        },
      },
      {
        r'$project': {'label': r'$_id', 'value': r'$count', '_id': 0},
      },
    ];
  }

  /// Creates a pipeline for reports grouped by reason within a date range.
  List<Map<String, dynamic>> _buildReportsByReasonPipeline(
    DateTime startDate,
    DateTime endDate,
  ) {
    return [
      {
        r'$match': {
          'createdAt': {
            r'$gte': startDate.toIso8601String(),
            r'$lt': endDate.toIso8601String(),
          },
        },
      },
      {
        r'$group': {
          '_id': r'$reason',
          'count': {r'$sum': 1},
        },
      },
      {
        r'$project': {'label': r'$_id', 'value': r'$count', '_id': 0},
      },
    ];
  }

  /// Creates a pipeline for reactions grouped by type within a date range.
  List<Map<String, dynamic>> _buildReactionsByTypePipeline(
    DateTime startDate,
    DateTime endDate,
  ) {
    return [
      {
        r'$match': {
          'createdAt': {
            r'$gte': startDate.toIso8601String(),
            r'$lt': endDate.toIso8601String(),
          },
          'reaction': {r'$exists': true},
        },
      },
      {
        r'$group': {
          '_id': r'$reaction.reactionType',
          'count': {r'$sum': 1},
        },
      },
      {
        r'$project': {'label': r'$_id', 'value': r'$count', '_id': 0},
      },
    ];
  }

  /// Creates a pipeline for app review feedback (positive vs. negative)
  /// within a date range.
  List<Map<String, dynamic>> _buildAppReviewFeedbackPipeline(
    DateTime startDate,
    DateTime endDate,
  ) {
    return [
      {
        r'$match': {
          'createdAt': {
            r'$gte': startDate.toIso8601String(),
            r'$lt': endDate.toIso8601String(),
          },
        },
      },
      {
        r'$group': {
          '_id': r'$feedback',
          'count': {r'$sum': 1},
        },
      },
      {
        r'$project': {'label': r'$_id', 'value': r'$count', '_id': 0},
      },
    ];
  }
}
