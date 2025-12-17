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
  AnalyticsQuery? getKpiQuery(KpiCardId kpiId) {
    return _kpiQueryMappings[kpiId];
  }

  /// Returns the query object for a given chart card.
  AnalyticsQuery? getChartQuery(ChartCardId chartId) {
    return _chartQueryMappings[chartId];
  }

  /// Returns the query object for a ranked list.
  AnalyticsQuery? getRankedListQuery(RankedListCardId rankedListId) {
    return _rankedListQueryMappings[rankedListId];
  }

  static final Map<KpiCardId, AnalyticsQuery> _kpiQueryMappings = {
    // User KPIs
    KpiCardId.usersTotalRegistered: const EventCountQuery(
      event: AnalyticsEvent.userRegistered,
    ),
    KpiCardId.usersNewRegistrations: const EventCountQuery(
      event: AnalyticsEvent.userRegistered,
    ),
    KpiCardId.usersActiveUsers: const StandardMetricQuery(metric: 'activeUsers'),
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
    KpiCardId.engagementsReportsAverageResolutionTime: const StandardMetricQuery(
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

  static final Map<ChartCardId, AnalyticsQuery> _chartQueryMappings = {
    // User Charts
    ChartCardId.usersRegistrationsOverTime: const EventCountQuery(
      event: AnalyticsEvent.userRegistered,
    ),
    ChartCardId.usersActiveUsersOverTime:
        const StandardMetricQuery(metric: 'activeUsers'),
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
    // Other charts are placeholders for now as they require more complex
    // queries or database-only aggregations not yet implemented.
    ChartCardId.contentHeadlinesViewsByTopic: null,
    ChartCardId.contentSourcesHeadlinesPublishedOverTime: null,
    ChartCardId.contentSourcesFollowersOverTime: null,
    ChartCardId.contentSourcesEngagementByType: null,
    ChartCardId.contentTopicsFollowersOverTime: null,
    ChartCardId.contentTopicsHeadlinesPublishedOverTime: null,
    ChartCardId.contentTopicsEngagementByTopic: null,
    ChartCardId.engagementsReactionsOverTime: null,
    ChartCardId.engagementsCommentsOverTime: null,
    ChartCardId.engagementsReactionsByType: null,
    ChartCardId.engagementsReportsSubmittedOverTime: null,
    ChartCardId.engagementsReportsResolutionTimeOverTime: null,
    ChartCardId.engagementsReportsByReason: null,
    ChartCardId.engagementsAppReviewsFeedbackOverTime: null,
    ChartCardId.engagementsAppReviewsPositiveVsNegative: null,
    ChartCardId.engagementsAppReviewsStoreRequestsOverTime: null,
  };

  static final Map<RankedListCardId, AnalyticsQuery>
      _rankedListQueryMappings = {
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
