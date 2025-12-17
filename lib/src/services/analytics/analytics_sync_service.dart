import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/analytics/analytics.dart';
import 'package:logging/logging.dart';

/// {@template analytics_sync_service}
/// The core orchestrator for the background worker.
///
/// This service reads the remote config to determine the active provider,
/// instantiates the correct reporting client, and iterates through all
/// [KpiCardId], [ChartCardId], and [RankedListCardId] enums.
///
/// For each ID, it fetches the corresponding data from the provider,
/// transforms it into the appropriate [KpiCardData], [ChartCardData], or
/// [RankedListCardData] model, and upserts it into the database using the
/// generic repositories. This service encapsulates the entire ETL (Extract,
/// Transform, Load) logic.
/// {@endtemplate}
class AnalyticsSyncService {
  /// {@macro analytics_sync_service}
  AnalyticsSyncService({
    required DataRepository<RemoteConfig> remoteConfigRepository,
    required DataRepository<KpiCardData> kpiCardRepository,
    required DataRepository<ChartCardData> chartCardRepository,
    required DataRepository<RankedListCardData> rankedListCardRepository,
    required DataRepository<Headline> headlineRepository,
    required AnalyticsReportingClient? googleAnalyticsClient,
    required AnalyticsReportingClient? mixpanelClient,
    required AnalyticsMetricMapper analyticsMetricMapper,
    required Logger log,
  }) : _remoteConfigRepository = remoteConfigRepository,
       _kpiCardRepository = kpiCardRepository,
       _chartCardRepository = chartCardRepository,
       _rankedListCardRepository = rankedListCardRepository,
       _headlineRepository = headlineRepository,
       _googleAnalyticsClient = googleAnalyticsClient,
       _mixpanelClient = mixpanelClient,
       _analyticsMetricMapper = analyticsMetricMapper,
       _log = log;

  final DataRepository<RemoteConfig> _remoteConfigRepository;
  final DataRepository<KpiCardData> _kpiCardRepository;
  final DataRepository<ChartCardData> _chartCardRepository;
  final DataRepository<RankedListCardData> _rankedListCardRepository;
  final DataRepository<Headline> _headlineRepository;
  final AnalyticsReportingClient? _googleAnalyticsClient;
  final AnalyticsReportingClient? _mixpanelClient;
  final AnalyticsMetricMapper _analyticsMetricMapper;
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

      await _syncKpiCards(client, analyticsConfig.activeProvider);
      await _syncChartCards(client, analyticsConfig.activeProvider);
      await _syncRankedListCards(client, analyticsConfig.activeProvider);

      _log.info('Analytics sync process completed successfully.');
    } catch (e, s) {
      _log.severe('Analytics sync process failed.', e, s);
    }
  }

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

  Future<void> _syncKpiCards(
    AnalyticsReportingClient client,
    AnalyticsProvider provider,
  ) async {
    _log.info('Syncing KPI cards...');
    for (final kpiId in KpiCardId.values) {
      try {
        final metrics = _analyticsMetricMapper.getKpiMetrics(kpiId, provider);
        if (metrics == null) {
          _log.finer('No metric mapping for KPI ${kpiId.name}. Skipping.');
          continue;
        }

        final timeFrames = <KpiTimeFrame, KpiTimeFrameData>{};
        final now = DateTime.now();

        for (final timeFrame in KpiTimeFrame.values) {
          final days = _daysForKpiTimeFrame(timeFrame);
          final startDate = now.subtract(Duration(days: days));
          final value = await client.getMetricTotal(
            metrics.metric,
            startDate,
            now,
          );

          final prevStartDate = startDate.subtract(Duration(days: days));
          final prevValue = await client.getMetricTotal(
            metrics.metric,
            prevStartDate,
            startDate,
          );

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

  Future<void> _syncChartCards(
    AnalyticsReportingClient client,
    AnalyticsProvider provider,
  ) async {
    _log.info('Syncing Chart cards...');
    for (final chartId in ChartCardId.values) {
      try {
        final metrics = _analyticsMetricMapper.getChartMetrics(
          chartId,
          provider,
        );
        if (metrics == null) {
          _log.finer('No metric mapping for Chart ${chartId.name}. Skipping.');
          continue;
        }

        final timeFrames = <ChartTimeFrame, List<DataPoint>>{};
        final now = DateTime.now();

        for (final timeFrame in ChartTimeFrame.values) {
          final days = _daysForChartTimeFrame(timeFrame);
          final startDate = now.subtract(Duration(days: days));
          final dataPoints = await client.getTimeSeries(
            metrics.metric,
            startDate,
            now,
          );
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

  Future<void> _syncRankedListCards(
    AnalyticsReportingClient client,
    AnalyticsProvider provider,
  ) async {
    _log.info('Syncing Ranked List cards...');
    for (final rankedListId in RankedListCardId.values) {
      try {
        final metrics = _analyticsMetricMapper.getRankedListMetrics(
          rankedListId,
          provider,
        );
        if (metrics == null || metrics.dimension == null) {
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
          final rawItems = await client.getRankedList(
            metrics.dimension!,
            metrics.metric,
            startDate,
            now,
          );

          final enrichedItems = await _enrichRankedListItems(rawItems);
          timeFrames[timeFrame] = enrichedItems;
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

  Future<List<RankedListItem>> _enrichRankedListItems(
    List<RankedListItem> items,
  ) async {
    if (items.isEmpty) return [];

    final headlineIds = items.map((item) => item.entityId).toList();
    final paginatedHeadlines = await _headlineRepository.readAll(
      filter: {
        '_id': {r'$in': headlineIds},
      },
    );

    final headlineMap = {
      for (final headline in paginatedHeadlines.items) headline.id: headline,
    };

    return items
        .map(
          (item) => item.copyWith(
            displayTitle: headlineMap[item.entityId]?.title ?? 'Unknown Title',
          ),
        )
        .toList();
  }

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

  String _calculateTrend(num currentValue, num previousValue) {
    if (previousValue == 0) {
      return currentValue > 0 ? '+100%' : '0%';
    }
    final percentageChange =
        ((currentValue - previousValue) / previousValue) * 100;
    return '${percentageChange.isNegative ? '' : '+'}'
        '${percentageChange.toStringAsFixed(1)}%';
  }

  String _formatLabel(String idName) => idName
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  ChartType _chartTypeForId(ChartCardId id) =>
      id.name.contains('distribution') || id.name.contains('by_')
      ? ChartType.bar
      : ChartType.line;
}
