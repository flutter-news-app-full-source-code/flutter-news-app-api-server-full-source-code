import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/analytics/analytics.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/analytics/analytics_query_builder.dart';
import 'package:logging/logging.dart';

/// {@template analytics_sync_service}
/// The core orchestrator for the background analytics worker.
///
/// This service reads the remote config to determine the active provider,
/// instantiates the correct reporting client, and iterates through all
/// [KpiCardId], [ChartCardId], and [RankedListCardId] enums.
///
/// For each ID, it fetches the corresponding data from the provider or the
/// local database, transforms it into the appropriate [KpiCardData],
/// [ChartCardData], or [RankedListCardData] model, and upserts it into the
/// database. This service encapsulates the entire ETL (Extract, Transform,
/// Load) logic for analytics.
///
/// It delegates the construction of complex database queries to an
/// [AnalyticsQueryBuilder] to keep this service clean and focused on
/// orchestration.
/// {@endtemplate}
class AnalyticsSyncService {
  /// {@macro analytics_sync_service}
  AnalyticsSyncService({
    required DataRepository<RemoteConfig> remoteConfigRepository,
    required DataRepository<KpiCardData> kpiCardRepository,
    required DataRepository<ChartCardData> chartCardRepository,
    required DataRepository<RankedListCardData> rankedListCardRepository,
    required DataRepository<User> userRepository,
    required DataRepository<Topic> topicRepository,
    required DataRepository<Report> reportRepository,
    required DataRepository<Source> sourceRepository,
    required DataRepository<Headline> headlineRepository,
    required DataRepository<Engagement> engagementRepository,
    required DataRepository<AppReview> appReviewRepository,
    required AnalyticsReportingClient? googleAnalyticsClient,
    required AnalyticsReportingClient? mixpanelClient,
    required AnalyticsMetricMapper analyticsMetricMapper,
    required Logger log,
  }) : _remoteConfigRepository = remoteConfigRepository,
       _kpiCardRepository = kpiCardRepository,
       _chartCardRepository = chartCardRepository,
       _rankedListCardRepository = rankedListCardRepository,
       _userRepository = userRepository,
       _topicRepository = topicRepository,
       _reportRepository = reportRepository,
       _sourceRepository = sourceRepository,
       _headlineRepository = headlineRepository,
       _engagementRepository = engagementRepository,
       _appReviewRepository = appReviewRepository,
       _googleAnalyticsClient = googleAnalyticsClient,
       _mixpanelClient = mixpanelClient,
       _mapper = analyticsMetricMapper,
       // The query builder is instantiated here as it is stateless.
       _queryBuilder = AnalyticsQueryBuilder(),
       _log = log;

  final DataRepository<RemoteConfig> _remoteConfigRepository;
  final DataRepository<KpiCardData> _kpiCardRepository;
  final DataRepository<ChartCardData> _chartCardRepository;
  final DataRepository<RankedListCardData> _rankedListCardRepository;
  final DataRepository<User> _userRepository;
  final DataRepository<Topic> _topicRepository;
  final DataRepository<Report> _reportRepository;
  final DataRepository<Source> _sourceRepository;
  final DataRepository<Headline> _headlineRepository;
  final DataRepository<Engagement> _engagementRepository;
  final DataRepository<AppReview> _appReviewRepository;
  final AnalyticsReportingClient? _googleAnalyticsClient;
  final AnalyticsReportingClient? _mixpanelClient;
  final AnalyticsMetricMapper _mapper;
  final AnalyticsQueryBuilder _queryBuilder;
  final Logger _log;

  /// Runs the entire analytics synchronization process.
  Future<void> run() async {
    _log.info('Starting analytics sync process...');

    try {
      final remoteConfig = await _remoteConfigRepository.read(
        id: kRemoteConfigId,
      );
      final analyticsConfig = remoteConfig.features.analytics;

      if (!analyticsConfig.enabled) {
        _log.info('Analytics is disabled in RemoteConfig. Skipping sync.');
        return;
      }

      final client = _getClient(analyticsConfig.activeProvider);
      if (client == null) {
        _log.warning(
          'Analytics provider "${analyticsConfig.activeProvider.name}" is '
          'configured, but its client is not available or initialized. '
          'Skipping sync.',
        );
        return;
      }

      _log.info(
        'Syncing analytics data using provider: '
        '"${analyticsConfig.activeProvider.name}".',
      );

      await _syncKpiCards(client);
      await _syncChartCards(client);
      await _syncRankedListCards(client);

      _log.info('Analytics sync process completed successfully.');
    } catch (e, s) {
      _log.severe('Analytics sync process failed.', e, s);
    }
  }

  /// Returns the appropriate analytics client based on the configured provider.
  AnalyticsReportingClient? _getClient(AnalyticsProvider provider) {
    switch (provider) {
      case AnalyticsProvider.firebase:
        return _googleAnalyticsClient;
      case AnalyticsProvider.mixpanel:
        return _mixpanelClient;
      case AnalyticsProvider.demo:
        return null;
    }
  }

  /// Syncs all KPI cards defined in [KpiCardId].
  Future<void> _syncKpiCards(AnalyticsReportingClient client) async {
    _log.info('Syncing KPI cards...');
    for (final kpiId in KpiCardId.values) {
      try {
        final query = _mapper.getKpiQuery(kpiId);
        if (query == null) {
          _log.finer('No metric mapping for KPI ${kpiId.name}. Skipping.');
          continue;
        }

        final isDatabaseQuery =
            query is StandardMetricQuery &&
            query.metric.startsWith('database:');

        final timeFrames = <KpiTimeFrame, KpiTimeFrameData>{};
        final now = DateTime.now();

        for (final timeFrame in KpiTimeFrame.values) {
          final days = _daysForKpiTimeFrame(timeFrame);
          final startDate = now.subtract(Duration(days: days));
          final prevPeriodStartDate = now.subtract(Duration(days: days * 2));
          final prevPeriodEndDate = startDate;

          num value;
          num prevValue;

          if (isDatabaseQuery) {
            value = await _getDatabaseMetricTotal(query, startDate, now);
            prevValue = await _getDatabaseMetricTotal(
              query,
              prevPeriodStartDate,
              prevPeriodEndDate,
            );
          } else {
            value = await client.getMetricTotal(query, startDate, now);
            prevValue = await client.getMetricTotal(
              query,
              prevPeriodStartDate,
              prevPeriodEndDate,
            );
          }

          final trend = _calculateTrend(value, prevValue);
          timeFrames[timeFrame] = KpiTimeFrameData(value: value, trend: trend);
        }

        final kpiCard = KpiCardData(
          id: kpiId,
          label: _formatLabel(kpiId.name),
          timeFrames: timeFrames,
        );

        await _kpiCardRepository.update(id: kpiId.name, item: kpiCard);
        _log.finer('Successfully synced KPI card: ${kpiId.name}');
      } catch (e, s) {
        _log.severe('Failed to sync KPI card: ${kpiId.name}', e, s);
      }
    }
  }

  /// Syncs all Chart cards defined in [ChartCardId].
  Future<void> _syncChartCards(AnalyticsReportingClient client) async {
    _log.info('Syncing Chart cards...');
    for (final chartId in ChartCardId.values) {
      try {
        final query = _mapper.getChartQuery(chartId);
        if (query == null) {
          _log.finer('No metric mapping for Chart ${chartId.name}. Skipping.');
          continue;
        }

        final isDatabaseQuery =
            query is StandardMetricQuery &&
            query.metric.startsWith('database:');

        final timeFrames = <ChartTimeFrame, List<DataPoint>>{};
        final now = DateTime.now();

        for (final timeFrame in ChartTimeFrame.values) {
          final days = _daysForChartTimeFrame(timeFrame);
          final startDate = now.subtract(Duration(days: days));
          List<DataPoint> dataPoints;

          if (isDatabaseQuery) {
            dataPoints = await _getDatabaseTimeSeries(query, startDate, now);
          } else {
            dataPoints = await client.getTimeSeries(query, startDate, now);
          }
          timeFrames[timeFrame] = dataPoints;
        }

        final chartCard = ChartCardData(
          id: chartId,
          label: _formatLabel(chartId.name),
          type: _chartTypeForId(chartId),
          timeFrames: timeFrames,
        );

        await _chartCardRepository.update(id: chartId.name, item: chartCard);
        _log.finer('Successfully synced Chart card: ${chartId.name}');
      } catch (e, s) {
        _log.severe('Failed to sync Chart card: ${chartId.name}', e, s);
      }
    }
  }

  /// Syncs all Ranked List cards defined in [RankedListCardId].
  Future<void> _syncRankedListCards(AnalyticsReportingClient client) async {
    _log.info('Syncing Ranked List cards...');
    for (final rankedListId in RankedListCardId.values) {
      try {
        final query = _mapper.getRankedListQuery(rankedListId);
        final isDatabaseQuery =
            query is StandardMetricQuery &&
            query.metric.startsWith('database:');

        if (query == null || (!isDatabaseQuery && query is! RankedListQuery)) {
          _log.finer(
            'No metric mapping for Ranked List ${rankedListId.name}. Skipping.',
          );
          continue;
        }

        final timeFrames = <RankedListTimeFrame, List<RankedListItem>>{};
        final now = DateTime.now();

        for (final timeFrame in RankedListTimeFrame.values) {
          final days = _daysForRankedListTimeFrame(timeFrame);
          final startDate = now.subtract(Duration(days: days));
          List<RankedListItem> items;

          if (isDatabaseQuery) {
            items = await _getDatabaseRankedList(
              query as StandardMetricQuery,
              startDate,
              now,
            );
          } else {
            items = await client.getRankedList(
              query as RankedListQuery,
              startDate,
              now,
            );
          }
          timeFrames[timeFrame] = items;
        }

        final rankedListCard = RankedListCardData(
          id: rankedListId,
          label: _formatLabel(rankedListId.name),
          timeFrames: timeFrames,
        );

        await _rankedListCardRepository.update(
          id: rankedListId.name,
          item: rankedListCard,
        );
        _log.finer(
          'Successfully synced Ranked List card: ${rankedListId.name}',
        );
      } catch (e, s) {
        _log.severe(
          'Failed to sync Ranked List card: ${rankedListId.name}',
          e,
          s,
        );
      }
    }
  }

  /// Calculates a total for a metric sourced from the local database.
  Future<num> _getDatabaseMetricTotal(
    StandardMetricQuery query,
    DateTime startDate,
    DateTime now,
  ) async {
    final filter = <String, dynamic>{
      'createdAt': {
        r'$gte': startDate.toIso8601String(),
        r'$lt': now.toIso8601String(),
      },
    };

    switch (query.metric) {
      case 'database:headlines':
        return _headlineRepository.count(filter: filter);
      case 'database:sources':
        return _sourceRepository.count(filter: filter);
      case 'database:topics':
        return _topicRepository.count(filter: filter);
      default:
        _log.warning('Unsupported database metric total: ${query.metric}');
        return 0;
    }
  }

  /// Fetches and transforms data for a chart sourced from the local database.
  Future<List<DataPoint>> _getDatabaseTimeSeries(
    StandardMetricQuery query,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final pipeline = _queryBuilder.buildPipelineForMetric(
      query,
      startDate,
      endDate,
    );
    if (pipeline == null) {
      _log.warning('Unsupported database time series: ${query.metric}');
      return [];
    }

    final repo = _getRepoForMetric(query.metric);
    final results = await repo.aggregate(pipeline: pipeline);
    return results.map(DataPoint.fromMap).toList();
  }

  /// Fetches and transforms data for a ranked list sourced from the local
  /// database.
  Future<List<RankedListItem>> _getDatabaseRankedList(
    StandardMetricQuery query,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // The date range is currently unused for these queries as they are
    // snapshots of all-time data (e.g., total followers). This could be
    // extended in the future if time-bound ranked lists are needed.
    switch (query.metric) {
      case 'database:sourcesByFollowers':
      case 'database:topicsByFollowers':
        final isTopics = query.metric.contains('topics');
        final pipeline = <Map<String, dynamic>>[
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
        ];
        final repo = isTopics ? _topicRepository : _sourceRepository;
        final results = await repo.aggregate(pipeline: pipeline);
        return results
            .map<RankedListItem>(
              (e) => RankedListItem(
                entityId: e['_id'] as String,
                displayTitle: e['name'] as String,
                metricValue: e['followerCount'] as int,
              ),
            )
            .toList();
      default:
        _log.warning('Unsupported database ranked list: ${query.metric}');
        return [];
    }
  }

  /// Returns the correct repository based on the metric name.
  /// This is used to direct database aggregation queries to the right collection.
  DataRepository<dynamic> _getRepoForMetric(String metric) {
    if (metric.contains('user')) return _userRepository;
    if (metric.contains('report')) return _reportRepository;
    if (metric.contains('reaction')) return _engagementRepository;
    if (metric.contains('appReview')) return _appReviewRepository;
    // Default to headline, source, or topic repos if needed, or add more cases.
    return _headlineRepository;
  }

  /// Returns the number of days for a given KPI time frame.
  int _daysForKpiTimeFrame(KpiTimeFrame timeFrame) {
    switch (timeFrame) {
      case KpiTimeFrame.day:
        return 1;
      case KpiTimeFrame.week:
        return 7;
      case KpiTimeFrame.month:
        return 30;
      case KpiTimeFrame.year:
        return 365;
    }
  }

  /// Returns the number of days for a given Chart time frame.
  int _daysForChartTimeFrame(ChartTimeFrame timeFrame) {
    switch (timeFrame) {
      case ChartTimeFrame.week:
        return 7;
      case ChartTimeFrame.month:
        return 30;
      case ChartTimeFrame.year:
        return 365;
    }
  }

  /// Returns the number of days for a given Ranked List time frame.
  int _daysForRankedListTimeFrame(RankedListTimeFrame timeFrame) {
    switch (timeFrame) {
      case RankedListTimeFrame.day:
        return 1;
      case RankedListTimeFrame.week:
        return 7;
      case RankedListTimeFrame.month:
        return 30;
      case RankedListTimeFrame.year:
        return 365;
    }
  }

  /// Calculates the trend as a percentage string.
  String _calculateTrend(num currentValue, num previousValue) {
    if (previousValue == 0) {
      return currentValue > 0 ? '+100.0%' : '0.0%';
    }
    final percentageChange =
        ((currentValue - previousValue) / previousValue) * 100;
    return '${percentageChange.isNegative ? '' : '+'}'
        '${percentageChange.toStringAsFixed(1)}%';
  }

  /// Formats an enum name into a human-readable label.
  String _formatLabel(String idName) => idName
      .replaceAll(RegExp(r'([A-Z])'), r' $1')
      .trim()
      .split('_')
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// Determines the chart type based on the ID name.
  ChartType _chartTypeForId(ChartCardId id) =>
      id.name.contains('distribution') || id.name.contains('By')
      ? ChartType.bar
      : ChartType.line;
}

/// An extension to capitalize strings.
extension on String {
  /// Capitalizes the first letter of the string.
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
