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

  /// Returns the chart type for a given chart card.
  ChartType getChartType(ChartCardId id) {
    final name = id.name.toLowerCase();
    // Check for keywords indicating categorical data (Bar Chart)
    // vs time-series data (Line Chart).
    return name.contains('distribution') ||
            name.contains('bytype') ||
            name.contains('by_')
        ? ChartType.bar
        : ChartType.line;
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
      metric: 'database:headlines:count',
    ),
    KpiCardId.contentHeadlinesTotalViews: const EventCountQuery(
      event: AnalyticsEvent.contentViewed,
    ),
    KpiCardId.contentHeadlinesTotalLikes: const EventCountQuery(
      event: AnalyticsEvent.reactionCreated,
    ),
    // Source KPIs
    KpiCardId.contentSourcesTotalSources: const StandardMetricQuery(
      metric: 'database:sources:count',
    ),
    KpiCardId.contentSourcesNewSources: const StandardMetricQuery(
      metric: 'database:sources:count',
    ),
    KpiCardId.contentSourcesTotalFollowers: const StandardMetricQuery(
      metric: 'database:sources:followers',
    ),
    // Topic KPIs
    KpiCardId.contentTopicsTotalTopics: const StandardMetricQuery(
      metric: 'database:topics:count',
    ),
    KpiCardId.contentTopicsNewTopics: const StandardMetricQuery(
      metric: 'database:topics:count',
    ),
    KpiCardId.contentTopicsTotalFollowers: const StandardMetricQuery(
      metric: 'database:topics:followers',
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
      metric: 'database:reports:pending',
    ),
    KpiCardId.engagementsReportsResolved: const StandardMetricQuery(
      metric: 'database:reports:resolved',
    ),
    KpiCardId.engagementsReportsAverageResolutionTime:
        const StandardMetricQuery(
          metric: 'database:reports:avgResolutionTime',
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
    // Rewards KPIs
    KpiCardId.rewardsAdsWatchedTotal: const EventCountQuery(
      event: AnalyticsEvent.adRewardEarned,
    ),
    KpiCardId.rewardsActiveUsersCount: const StandardMetricQuery(
      metric: 'database:user_rewards:active_count',
    ),
    KpiCardId.rewardsGrantedTotal: const EventCountQuery(
      event: AnalyticsEvent.rewardGranted,
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
    ChartCardId.usersTierDistribution: const StandardMetricQuery(
      metric: 'database:users:userTierDistribution',
    ),
    // Headline Charts
    ChartCardId.contentHeadlinesViewsOverTime: const EventCountQuery(
      event: AnalyticsEvent.contentViewed,
    ),
    ChartCardId.contentHeadlinesLikesOverTime: const EventCountQuery(
      event: AnalyticsEvent.reactionCreated,
    ),
    ChartCardId.contentHeadlinesViewsByTopic: const StandardMetricQuery(
      metric: 'database:headlines:viewsByTopic',
    ),
    // Sources Tab
    ChartCardId.contentSourcesHeadlinesPublishedOverTime:
        const StandardMetricQuery(
          metric: 'database:headlines:bySource',
        ),
    ChartCardId.contentSourcesEngagementByType: const StandardMetricQuery(
      metric: 'database:sources:engagementByType',
    ),
    ChartCardId.contentSourcesStatusDistribution: const StandardMetricQuery(
      metric: 'database:sources:statusDistribution',
    ),
    // Topics Tab
    ChartCardId.contentTopicsHeadlinesPublishedOverTime:
        const StandardMetricQuery(
          metric: 'database:headlines:byTopic',
        ),
    ChartCardId.contentTopicsEngagementByTopic: const StandardMetricQuery(
      metric: 'database:headlines:topicEngagement',
    ),
    ChartCardId.contentHeadlinesBreakingNewsDistribution:
        const StandardMetricQuery(
          metric: 'database:headlines:breakingNewsDistribution',
        ),
    // Engagements Tab
    ChartCardId.engagementsReactionsOverTime: const EventCountQuery(
      event: AnalyticsEvent.reactionCreated,
    ),
    ChartCardId.engagementsCommentsOverTime: const EventCountQuery(
      event: AnalyticsEvent.commentCreated,
    ),
    ChartCardId.engagementsReactionsByType: const StandardMetricQuery(
      metric: 'database:engagements:reactionsByType',
    ),
    // Reports Tab
    ChartCardId.engagementsReportsSubmittedOverTime: const EventCountQuery(
      event: AnalyticsEvent.reportSubmitted,
    ),
    ChartCardId.engagementsReportsResolutionTimeOverTime:
        const StandardMetricQuery(metric: 'database:reports:avgResolutionTime'),
    ChartCardId.engagementsReportsByReason: const StandardMetricQuery(
      metric: 'database:reports:byReason',
    ),
    // App Reviews Tab
    ChartCardId.engagementsAppReviewsFeedbackOverTime: const EventCountQuery(
      event: AnalyticsEvent.appReviewPromptResponded,
    ),
    ChartCardId.engagementsAppReviewsPositiveVsNegative:
        const StandardMetricQuery(
          metric: 'database:app_reviews:feedback',
        ),
    ChartCardId.engagementsAppReviewsStoreRequestsOverTime:
        const EventCountQuery(
          event: AnalyticsEvent.appReviewStoreRequested,
        ),
    // Rewards Tab
    ChartCardId.rewardsAdsWatchedOverTime: const EventCountQuery(
      event: AnalyticsEvent.adRewardEarned,
    ),
    ChartCardId.rewardsActiveByType: const StandardMetricQuery(
      metric: 'database:user_rewards:active_by_type',
    ),
    ChartCardId.rewardsGrantedOverTime: const EventCountQuery(
      event: AnalyticsEvent.rewardGranted,
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
          metric: 'database:sources:byFollowers',
        ),
        RankedListCardId.overviewTopicsMostFollowed: const StandardMetricQuery(
          metric: 'database:topics:byFollowers',
        ),
      };
}
