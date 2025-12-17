import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart';

/// {@template analytics_metric_mapper}
/// Maps internal analytics card IDs to structured [AnalyticsQuery] objects.
///
/// This centralizes the "dictionary" of what to query for each card,
/// decoupling the sync service from the implementation details of each
/// analytics provider.
/// {@endtemplate}
class AnalyticsMetricMapper {
  /// Returns the query object for a given KPI card.
  MetricQuery? getKpiQuery(KpiCardId kpiId) {
    return _kpiQueryMappings[kpiId];
  }

  /// Returns the query object for a given chart card.
  MetricQuery? getChartQuery(ChartCardId chartId) {
    return _chartQueryMappings[chartId];
  }

  /// Returns the query object for a ranked list.
  AnalyticsQuery? getRankedListQuery(
    RankedListCardId rankedListId,
  ) {
    return _rankedListQueryMappings[rankedListId];
  }

  static final Map<KpiCardId, MetricQuery> _kpiQueryMappings = {
    // User KPIs
    KpiCardId.usersTotalRegistered: const EventCountQuery(
      event: AnalyticsEvent.userRegistered,
    ),
    KpiCardId.usersNewRegistrations: const EventCountQuery(
      event: AnalyticsEvent.userRegistered,
    ),
    KpiCardId.usersActiveUsers: const StandardMetricQuery(
      metric: 'activeUsers',
    ),
    // Headline KPIs
    KpiCardId.contentHeadlinesTotalPublished: const StandardMetricQuery(
      metric: 'database:headlines',
    ),
    KpiCardId.contentHeadlinesTotalViews: const EventCountQuery(
      event: AnalyticsEvent.contentViewed,
    ),
    KpiCardId.contentHeadlinesTotalLikes: const EventCountQuery(
      event: AnalyticsEvent.reactionCreated,
    ),
    // Source KPIs
    KpiCardId.contentSourcesTotalSources: const StandardMetricQuery(
      metric: 'database:sources',
    ),
    KpiCardId.contentSourcesNewSources: const StandardMetricQuery(
      metric: 'database:sources',
    ),
    KpiCardId.contentSourcesTotalFollowers: const StandardMetricQuery(
      metric: 'database:sourceFollowers',
    ),
    // Topic KPIs
    KpiCardId.contentTopicsTotalTopics: const StandardMetricQuery(
      metric: 'database:topics',
    ),
    KpiCardId.contentTopicsNewTopics: const StandardMetricQuery(
      metric: 'database:topics',
    ),
    KpiCardId.contentTopicsTotalFollowers: const StandardMetricQuery(
      metric: 'database:topicFollowers',
    ),
    // Engagement KPIs
    KpiCardId.engagementsTotalReactions: const EventCountQuery(
      event: AnalyticsEvent.reactionCreated,
    ),
    KpiCardId.engagementsTotalComments: const EventCountQuery(
      event: AnalyticsEvent.commentCreated,
    ),
    KpiCardId.engagementsAverageEngagementRate: const StandardMetricQuery(
      metric: 'calculated:engagementRate',
    ),
    // Report KPIs
    KpiCardId.engagementsReportsPending: const StandardMetricQuery(
      metric: 'database:reportsPending',
    ),
    KpiCardId.engagementsReportsResolved: const StandardMetricQuery(
      metric: 'database:reportsResolved',
    ),
    KpiCardId.engagementsReportsAverageResolutionTime:
        const StandardMetricQuery(
          metric: 'database:avgReportResolutionTime',
        ),
    // App Review KPIs
    KpiCardId.engagementsAppReviewsTotalFeedback: const EventCountQuery(
      event: AnalyticsEvent.appReviewPromptResponded,
    ),
    KpiCardId.engagementsAppReviewsPositiveFeedback: const EventCountQuery(
      event: AnalyticsEvent.appReviewPromptResponded,
    ),
    KpiCardId.engagementsAppReviewsStoreRequests: const EventCountQuery(
      event: AnalyticsEvent.appReviewStoreRequested,
    ),
  };

  static final Map<ChartCardId, MetricQuery> _chartQueryMappings = {
    // User Charts
    ChartCardId.usersRegistrationsOverTime: const EventCountQuery(
      event: AnalyticsEvent.userRegistered,
    ),
    ChartCardId.usersActiveUsersOverTime: const StandardMetricQuery(
      metric: 'activeUsers',
    ),
    ChartCardId.usersRoleDistribution: const StandardMetricQuery(
      metric: 'database:userRoleDistribution',
    ),
    // Headline Charts
    ChartCardId.contentHeadlinesViewsOverTime: const EventCountQuery(
      event: AnalyticsEvent.contentViewed,
    ),
    ChartCardId.contentHeadlinesLikesOverTime: const EventCountQuery(
      event: AnalyticsEvent.reactionCreated,
    ),
    ChartCardId.contentHeadlinesViewsByTopic: const StandardMetricQuery(
      metric: 'database:viewsByTopic',
    ),
    // Sources Tab
    ChartCardId.contentSourcesHeadlinesPublishedOverTime:
        const StandardMetricQuery(
          metric: 'database:headlinesBySource',
        ),
    ChartCardId.contentSourcesEngagementByType: const StandardMetricQuery(
      metric: 'database:sourceEngagementByType',
    ),
    ChartCardId.content_sources_status_distribution: const StandardMetricQuery(
      metric: 'database:sourceStatusDistribution',
    ),
    // Topics Tab
    ChartCardId.contentTopicsHeadlinesPublishedOverTime:
        const StandardMetricQuery(
          metric: 'database:headlinesByTopic',
        ),
    ChartCardId.content_headlines_breaking_news_distribution:
        const StandardMetricQuery(
          metric: 'database:breakingNewsDistribution',
        ),
    // Engagements Tab
    ChartCardId.engagementsReactionsOverTime: const EventCountQuery(
      event: AnalyticsEvent.reactionCreated,
    ),
    ChartCardId.engagementsCommentsOverTime: const EventCountQuery(
      event: AnalyticsEvent.commentCreated,
    ),
    ChartCardId.engagementsReactionsByType: const StandardMetricQuery(
      metric: 'database:reactionsByType',
    ),
    // Reports Tab
    ChartCardId.engagementsReportsSubmittedOverTime: const EventCountQuery(
      event: AnalyticsEvent.reportSubmitted,
    ),
    ChartCardId.engagementsReportsResolutionTimeOverTime:
        const StandardMetricQuery(metric: 'database:avgReportResolutionTime'),
    ChartCardId.engagementsReportsByReason: const StandardMetricQuery(
      metric: 'database:reportsByReason',
    ),
    // App Reviews Tab
    ChartCardId.engagementsAppReviewsFeedbackOverTime: const EventCountQuery(
      event: AnalyticsEvent.appReviewPromptResponded,
    ),
    ChartCardId.engagementsAppReviewsPositiveVsNegative:
        const StandardMetricQuery(
          metric: 'database:appReviewFeedback',
        ),
    ChartCardId.engagementsAppReviewsStoreRequestsOverTime:
        const EventCountQuery(
          event: AnalyticsEvent.appReviewStoreRequested,
        ),
  };

  static final Map<RankedListCardId, AnalyticsQuery> _rankedListQueryMappings =
      {
        RankedListCardId.overviewHeadlinesMostViewed: const RankedListQuery(
          event: AnalyticsEvent.contentViewed,
          dimension: 'contentId',
        ),
        RankedListCardId.overviewHeadlinesMostLiked: const RankedListQuery(
          event: AnalyticsEvent.reactionCreated,
          dimension: 'contentId',
        ),
        // These require database-only aggregations.
        RankedListCardId.overviewSourcesMostFollowed: const StandardMetricQuery(
          metric: 'database:sourcesByFollowers',
        ),
        RankedListCardId.overviewTopicsMostFollowed: const StandardMetricQuery(
          metric: 'database:topicsByFollowers',
        ),
      };
}
