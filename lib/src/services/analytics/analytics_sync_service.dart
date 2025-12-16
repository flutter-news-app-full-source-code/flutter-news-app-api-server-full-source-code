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
    required AnalyticsReportingClient? googleAnalyticsClient,
    required AnalyticsReportingClient? mixpanelClient,
    required Logger log,
  }) : _remoteConfigRepository = remoteConfigRepository,
       _kpiCardRepository = kpiCardRepository,
       _chartCardRepository = chartCardRepository,
       _rankedListCardRepository = rankedListCardRepository,
       _googleAnalyticsClient = googleAnalyticsClient,
       _mixpanelClient = mixpanelClient,
       _log = log;

  final DataRepository<RemoteConfig> _remoteConfigRepository;
  final DataRepository<KpiCardData> _kpiCardRepository;
  final DataRepository<ChartCardData> _chartCardRepository;
  final DataRepository<RankedListCardData> _rankedListCardRepository;
  final AnalyticsReportingClient? _googleAnalyticsClient;
  final AnalyticsReportingClient? _mixpanelClient;
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
      // In a production environment, this might trigger an alert.
    }
  }

  AnalyticsReportingClient? _getClient(AnalyticsProvider provider) {
    switch (provider) {
      case AnalyticsProvider.firebase:
        return _googleAnalyticsClient;
      case AnalyticsProvider.mixpanel:
        return _mixpanelClient;
      case AnalyticsProvider.demo:
        return null; // Demo is intended for the mobile client demo env.
    }
  }

  Future<void> _syncKpiCards(AnalyticsReportingClient client) async {
    _log.info('Syncing KPI cards...');
    for (final kpiId in KpiCardId.values) {
      try {
        // This is a placeholder implementation.
        // A real implementation would map each kpiId to a specific metric
        // and fetch data for each time frame.
        final timeFrames = {
          KpiTimeFrame.day: const KpiTimeFrameData(value: 0, trend: '0%'),
          KpiTimeFrame.week: const KpiTimeFrameData(value: 0, trend: '0%'),
          KpiTimeFrame.month: const KpiTimeFrameData(value: 0, trend: '0%'),
          KpiTimeFrame.year: const KpiTimeFrameData(value: 0, trend: '0%'),
        };

        final kpiCard = KpiCardData(
          id: kpiId,
          label: kpiId.name, // Placeholder label
          timeFrames: timeFrames,
        );

        await _kpiCardRepository.update(
          id: kpiId.name,
          item: kpiCard,
          upsert: true,
        );
        _log.finer('Successfully synced KPI card: ${kpiId.name}');
      } catch (e, s) {
        _log.severe('Failed to sync KPI card: ${kpiId.name}', e, s);
      }
    }
  }

  Future<void> _syncChartCards(AnalyticsReportingClient client) async {
    _log.info('Syncing Chart cards...');
    for (final chartId in ChartCardId.values) {
      try {
        // Placeholder implementation
        final timeFrames = {
          ChartTimeFrame.week: <DataPoint>[],
          ChartTimeFrame.month: <DataPoint>[],
          ChartTimeFrame.year: <DataPoint>[],
        };

        final chartCard = ChartCardData(
          id: chartId,
          label: chartId.name, // Placeholder
          type: ChartType.line, // Placeholder
          timeFrames: timeFrames,
        );

        await _chartCardRepository.update(
          id: chartId.name,
          item: chartCard,
          upsert: true,
        );
        _log.finer('Successfully synced Chart card: ${chartId.name}');
      } catch (e, s) {
        _log.severe('Failed to sync Chart card: ${chartId.name}', e, s);
      }
    }
  }

  Future<void> _syncRankedListCards(AnalyticsReportingClient client) async {
    _log.info('Syncing Ranked List cards...');
    for (final rankedListId in RankedListCardId.values) {
      try {
        // Placeholder implementation
        final timeFrames = {
          RankedListTimeFrame.day: <RankedListItem>[],
          RankedListTimeFrame.week: <RankedListItem>[],
          RankedListTimeFrame.month: <RankedListItem>[],
          RankedListTimeFrame.year: <RankedListItem>[],
        };

        final rankedListCard = RankedListCardData(
          id: rankedListId,
          label: rankedListId.name, // Placeholder
          timeFrames: timeFrames,
        );

        await _rankedListCardRepository.update(
          id: rankedListId.name,
          item: rankedListCard,
          upsert: true,
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
}
