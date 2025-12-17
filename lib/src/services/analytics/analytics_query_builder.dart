import 'package:flutter_news_app_api_server_full_source_code/src/models/analytics/analytics.dart';
import 'package:logging/logging.dart';

/// {@template analytics_query_builder}
/// A builder class responsible for creating complex MongoDB aggregation
/// pipelines for analytics queries.
///
/// This class centralizes the query logic, decoupling the
/// `AnalyticsSyncService` from the specific implementation details of
/// database aggregations.
/// {@endtemplate}
class AnalyticsQueryBuilder {
  final _log = Logger('AnalyticsQueryBuilder');

  /// Creates a MongoDB aggregation pipeline for a given database metric.
  ///
  /// Returns `null` if the metric is not a supported database query.
  List<Map<String, dynamic>>? buildPipelineForMetric(
    StandardMetricQuery query,
    DateTime startDate,
    DateTime endDate,
  ) {
    final metric = query.metric;
    _log.finer('Building pipeline for database metric: "$metric".');

    switch (metric) {
      case 'database:userRoleDistribution':
        _log.info('Building user role distribution pipeline.');
        return _buildUserRoleDistributionPipeline();
      case 'database:reportsByReason':
        _log.info(
          'Building reports by reason pipeline from $startDate to $endDate.',
        );
        return _buildReportsByReasonPipeline(startDate, endDate);
      case 'database:reactionsByType':
        _log.info(
          'Building reactions by type pipeline from $startDate to $endDate.',
        );
        return _buildReactionsByTypePipeline(startDate, endDate);
      case 'database:appReviewFeedback':
        _log.info(
          'Building app review feedback pipeline from $startDate to $endDate.',
        );
        return _buildAppReviewFeedbackPipeline(startDate, endDate);
      case 'database:avgReportResolutionTime':
        return _buildAvgReportResolutionTimePipeline(startDate, endDate);
      case 'database:viewsByTopic':
        return _buildCategoricalCountPipeline(
          collection: 'headlines',
          dateField: 'createdAt',
          groupByField: r'$topic.name',
          startDate: startDate,
          endDate: endDate,
        );
      case 'database:headlinesBySource':
        return _buildCategoricalCountPipeline(
          collection: 'headlines',
          dateField: 'createdAt',
          groupByField: r'$source.name',
          startDate: startDate,
          endDate: endDate,
        );
      case 'database:sourceEngagementByType':
        return _buildCategoricalCountPipeline(
          collection: 'sources',
          dateField: 'createdAt',
          groupByField: r'$sourceType',
          startDate: startDate,
          endDate: endDate,
        );
      case 'database:headlinesByTopic':
        return _buildCategoricalCountPipeline(
          collection: 'headlines',
          dateField: 'createdAt',
          groupByField: r'$topic.name',
          startDate: startDate,
          endDate: endDate,
        );
      case 'database:sourceStatusDistribution':
        _log.info(
          'Building categorical count pipeline for source status distribution.',
        );
        return _buildCategoricalCountPipeline(
          collection: 'sources',
          dateField: 'createdAt',
          groupByField: r'$status',
          startDate: startDate,
          endDate: endDate,
        );
      case 'database:breakingNewsDistribution':
        _log.info(
          'Building categorical count pipeline for breaking news distribution.',
        );
        return _buildCategoricalCountPipeline(
          collection: 'headlines',
          dateField: 'createdAt',
          groupByField: r'$isBreaking',
          startDate: startDate,
          endDate: endDate,
        );
      // Ranked List Queries
      case 'database:sourcesByFollowers':
        _log.info('Building ranked list pipeline for sources by followers.');
        return _buildRankedByFollowersPipeline('sources');
      case 'database:topicsByFollowers':
        _log.info('Building ranked list pipeline for topics by followers.');
        return _buildRankedByFollowersPipeline('topics');

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
            r'$gte': startDate.toUtc().toIso8601String(),
            r'$lt': endDate.toUtc().toIso8601String(),
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
            r'$gte': startDate.toUtc().toIso8601String(),
            r'$lt': endDate.toUtc().toIso8601String(),
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
            r'$gte': startDate.toUtc().toIso8601String(),
            r'$lt': endDate.toUtc().toIso8601String(),
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

  /// Creates a pipeline for ranking items by follower count.
  List<Map<String, dynamic>> _buildRankedByFollowersPipeline(String model) {
    // This pipeline calculates the number of followers for each document
    // by getting the size of the `followerIds` array, sorts them,
    // and projects them into the RankedListItem shape.
    return [
      {
        r'$project': {
          'name': 1,
          'followerCount': {r'$size': r'$followerIds'},
        },
      },
      {
        r'$sort': {'followerCount': -1},
      },
      {r'$limit': 5},
      {
        r'$project': {
          'entityId': r'$_id',
          'displayTitle': r'$name',
          'metricValue': r'$followerCount',
        },
      },
    ];
  }

  /// Creates a generic pipeline for counting occurrences of a categorical
  /// field.
  List<Map<String, dynamic>> _buildCategoricalCountPipeline({
    required String collection,
    required String dateField,
    required String groupByField,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return [
      {
        r'$match': {
          dateField: {
            r'$gte': startDate.toUtc().toIso8601String(),
            r'$lt': endDate.toUtc().toIso8601String(),
          },
        },
      },
      {
        r'$group': {
          '_id': groupByField,
          'count': {r'$sum': 1},
        },
      },
      {
        r'$project': {
          'label': r'$_id',
          'value': r'$count',
          '_id': 0,
        },
      },
    ];
  }

  /// Creates a pipeline for calculating the average report resolution time.
  List<Map<String, dynamic>> _buildAvgReportResolutionTimePipeline(
    DateTime startDate,
    DateTime endDate,
  ) {
    _log.info(
      'Building average report resolution time pipeline from $startDate '
      'to $endDate.',
    );
    return [
      // Match reports resolved within the date range
      {
        r'$match': {
          'status': 'resolved',
          'updatedAt': {
            r'$gte': startDate.toUtc().toIso8601String(),
            r'$lt': endDate.toUtc().toIso8601String(),
          },
        },
      },
      // Group by the date part of 'updatedAt'
      {
        r'$group': {
          '_id': {
            r'$dateToString': {
              'format': '%Y-%m-%d',
              'date': r'$updatedAt',
            },
          },
          // Calculate the average difference between 'updatedAt' and
          // 'createdAt' in milliseconds for each day.
          'avgResolutionTime': {
            r'$avg': {
              r'$subtract': [r'$updatedAt', r'$createdAt'],
            },
          },
        },
      },
      // Convert the average time from milliseconds to hours
      {
        r'$project': {
          'label': r'$_id',
          'value': {
            r'$divide': [
              r'$avgResolutionTime',
              3600000, // 1000ms * 60s * 60m
            ],
          },
          '_id': 0,
        },
      },
      // Sort by date
      {
        r'$sort': {'label': 1},
      },
    ];
  }
}
