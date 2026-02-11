import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/analytics/analytics_reporting_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/analytics/analytics.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

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
/// Transform, Load) logic for analytics.
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
    required DataRepository<UserRewards> userRewardsRepository,
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
       _userRewardsRepository = userRewardsRepository,
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
  final DataRepository<UserRewards> _userRewardsRepository;
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
  AnalyticsReportingClient? _getClient(AnalyticsProviders provider) {
    switch (provider) {
      case AnalyticsProviders.firebase:
        return _googleAnalyticsClient;
      case AnalyticsProviders.mixpanel:
        return _mixpanelClient;
    }
  }

  /// A helper to ensure the aggregation pipeline has the correct type.
  ///
  /// The underlying data client expects a `List<Map<String, Object>>`. This
  /// method performs an explicit deep conversion of the pipeline to ensure
  /// type compatibility before passing it to the repository.
  Future<List<Map<String, dynamic>>> _aggregate(
    DataRepository<dynamic> repository, {
    required List<Map<String, dynamic>> pipeline,
  }) {
    final correctlyTypedPipeline = pipeline
        .map(Map<String, Object>.from)
        .toList();
    return repository.aggregate(
      pipeline: correctlyTypedPipeline,
    );
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

        final isCalculatedQuery =
            query is StandardMetricQuery &&
            query.metric.startsWith('calculated:');

        final timeFrames = <KpiTimeFrame, KpiTimeFrameData>{};
        final now = DateTime.now();

        if (isDatabaseQuery || isCalculatedQuery) {
          // Batching for DB/calculated queries is more complex.
          // Handle them individually for now.
          for (final timeFrame in KpiTimeFrame.values) {
            final days = _daysForKpiTimeFrame(timeFrame);
            final startDate = now.subtract(Duration(days: days));
            final prevPeriodStartDate = now.subtract(Duration(days: days * 2));
            final prevPeriodEndDate = startDate;

            final value = isDatabaseQuery
                ? await _getDatabaseMetricTotal(query, startDate, now)
                : await _getCalculatedMetricTotal(
                    query,
                    startDate,
                    now,
                    client,
                  );

            final prevValue = isDatabaseQuery
                ? await _getDatabaseMetricTotal(
                    query,
                    prevPeriodStartDate,
                    prevPeriodEndDate,
                  )
                : await _getCalculatedMetricTotal(
                    query,
                    prevPeriodStartDate,
                    prevPeriodEndDate,
                    client,
                  );

            final trend = _calculateTrend(value, prevValue);
            timeFrames[timeFrame] = KpiTimeFrameData(
              value: value,
              trend: trend,
            );
          }
        } else {
          // N+1 Optimization: Batch API calls for all time frames and periods.
          final rangesToFetch = <GARequestDateRange>[];
          final periodMap =
              <
                KpiTimeFrame,
                ({GARequestDateRange current, GARequestDateRange previous})
              >{};

          for (final timeFrame in KpiTimeFrame.values) {
            final days = _daysForKpiTimeFrame(timeFrame);
            final currentStartDate = now.subtract(Duration(days: days));
            final previousStartDate = now.subtract(Duration(days: days * 2));

            final currentRange = GARequestDateRange.from(
              start: currentStartDate,
              end: now,
            );
            final previousRange = GARequestDateRange.from(
              start: previousStartDate,
              end: currentStartDate,
            );

            rangesToFetch.addAll([currentRange, previousRange]);
            periodMap[timeFrame] = (
              current: currentRange,
              previous: previousRange,
            );
          }

          final results = await client.getMetricTotalsBatch(
            query,
            rangesToFetch,
          );

          for (final timeFrame in KpiTimeFrame.values) {
            final periods = periodMap[timeFrame]!;
            final value = results[periods.current] ?? 0;
            final prevValue = results[periods.previous] ?? 0;
            final trend = _calculateTrend(value, prevValue);
            timeFrames[timeFrame] = KpiTimeFrameData(
              value: value,
              trend: trend,
            );
          }
        }

        // Upsert logic: Check if the card exists, then update or create.
        final existingCards = await _kpiCardRepository.readAll(
          filter: {'cardId': kpiId.name},
          pagination: const PaginationOptions(limit: 1),
        );

        final existingCard = existingCards.items.firstOrNull;

        if (existingCard != null) {
          final updatedCard = existingCard.copyWith(
            label: _formatLabel(kpiId.name),
            timeFrames: timeFrames,
          );
          await _kpiCardRepository.update(
            id: existingCard.id,
            item: updatedCard,
          );
        } else {
          final newCard = KpiCardData(
            id: ObjectId().oid,
            cardId: kpiId,
            label: _formatLabel(kpiId.name),
            timeFrames: timeFrames,
          );
          await _kpiCardRepository.create(item: newCard);
        }
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

        if (isDatabaseQuery) {
          // For DB queries, batching is more complex as pipelines differ.
          // We will handle them individually for now.
          for (final timeFrame in ChartTimeFrame.values) {
            final days = _daysForChartTimeFrame(timeFrame);
            final startDate = now.subtract(Duration(days: days));
            timeFrames[timeFrame] = await _getDatabaseTimeSeries(
              query,
              startDate,
              now,
            );
          }
        } else {
          // N+1 Optimization: Batch API calls for all time frames.
          final rangesToFetch = <GARequestDateRange>[];
          final rangeMap = <ChartTimeFrame, GARequestDateRange>{};

          for (final timeFrame in ChartTimeFrame.values) {
            final days = _daysForChartTimeFrame(timeFrame);
            final startDate = now.subtract(Duration(days: days));
            final range = GARequestDateRange.from(start: startDate, end: now);
            rangesToFetch.add(range);
            rangeMap[timeFrame] = range;
          }

          final results = await client.getTimeSeriesBatch(query, rangesToFetch);

          for (final timeFrame in ChartTimeFrame.values) {
            final range = rangeMap[timeFrame]!;
            timeFrames[timeFrame] = results[range] ?? [];
          }
        }

        final existingCards = await _chartCardRepository.readAll(
          filter: {'cardId': chartId.name},
          pagination: const PaginationOptions(limit: 1),
        );

        final existingCard = existingCards.items.firstOrNull;

        if (existingCard != null) {
          final updatedCard = existingCard.copyWith(
            label: _formatLabel(chartId.name),
            type: _mapper.getChartType(chartId),
            timeFrames: timeFrames,
          );
          await _chartCardRepository.update(
            id: existingCard.id,
            item: updatedCard,
          );
        } else {
          final newCard = ChartCardData(
            id: ObjectId().oid,
            cardId: chartId,
            label: _formatLabel(chartId.name),
            type: _mapper.getChartType(chartId),
            timeFrames: timeFrames,
          );
          await _chartCardRepository.create(item: newCard);
        }
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

        // Optimization: For non-temporal DB queries, fetch data only once.
        final isNonTemporalDbQuery =
            isDatabaseQuery && query.metric.endsWith(':byFollowers');

        final timeFrames = <RankedListTimeFrame, List<RankedListItem>>{};
        final now = DateTime.now();

        List<RankedListItem>? nonTemporalItems;
        if (isNonTemporalDbQuery) {
          // Dates are irrelevant for this query, but required by the method.
          nonTemporalItems = await _getDatabaseRankedList(query, now, now);
        }

        for (final timeFrame in RankedListTimeFrame.values) {
          final days = _daysForRankedListTimeFrame(timeFrame);
          final startDate = now.subtract(Duration(days: days));
          List<RankedListItem> items;

          if (nonTemporalItems != null) {
            items = nonTemporalItems;
          } else if (isDatabaseQuery) {
            items = await _getDatabaseRankedList(query, startDate, now);
          } else {
            items = await client.getRankedList(
              query as RankedListQuery,
              startDate,
              now,
            );
          }
          timeFrames[timeFrame] = items;
        }

        final existingCards = await _rankedListCardRepository.readAll(
          filter: {'cardId': rankedListId.name},
          pagination: const PaginationOptions(limit: 1),
        );

        final existingCard = existingCards.items.firstOrNull;

        if (existingCard != null) {
          final updatedCard = existingCard.copyWith(
            label: _formatLabel(rankedListId.name),
            timeFrames: timeFrames,
          );
          await _rankedListCardRepository.update(
            id: existingCard.id,
            item: updatedCard,
          );
        } else {
          final newCard = RankedListCardData(
            id: ObjectId().oid,
            cardId: rankedListId,
            label: _formatLabel(rankedListId.name),
            timeFrames: timeFrames,
          );
          await _rankedListCardRepository.create(item: newCard);
        }
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

  Future<num> _getDatabaseMetricTotal(
    StandardMetricQuery query,
    DateTime startDate,
    DateTime now,
  ) async {
    _log.finer(
      'Executing database metric total query for: ${query.metric}',
    );
    final filter = <String, dynamic>{
      'createdAt': {
        r'$gte': startDate.toIso8601String(),
        r'$lt': now.toIso8601String(),
      },
    };

    switch (query.metric) {
      case 'database:headlines:count':
        return _headlineRepository.count(filter: filter);
      case 'database:sources:count':
        return _sourceRepository.count(filter: filter);
      case 'database:topics:count':
        return _topicRepository.count(filter: filter);
      case 'database:sources:followers':
        // This requires aggregation to sum the size of all follower arrays.
        final pipeline = [
          {
            r'$project': {
              'followerCount': {
                r'$size': {
                  // ignore: inference_failure_on_collection_literal
                  r'$ifNull': [r'$followerIds', []],
                },
              },
            },
          },
          {
            r'$group': {
              '_id': null,
              'total': {r'$sum': r'$followerCount'},
            },
          },
        ];
        final result = await _aggregate(_sourceRepository, pipeline: pipeline);
        return result.firstOrNull?['total'] as num? ?? 0;
      case 'database:topics:followers':
        final pipeline = [
          {
            r'$project': {
              'followerCount': {
                r'$size': {
                  // ignore: inference_failure_on_collection_literal
                  r'$ifNull': [r'$followerIds', []],
                },
              },
            },
          },
          {
            r'$group': {
              '_id': null,
              'total': {r'$sum': r'$followerCount'},
            },
          },
        ];
        final result = await _aggregate(_topicRepository, pipeline: pipeline);
        return result.firstOrNull?['total'] as num? ?? 0;
      case 'database:reports:pending':
        return _reportRepository.count(
          filter: {'status': ModerationStatus.pendingReview.name},
        );
      case 'database:reports:resolved':
        return _reportRepository.count(
          filter: {'status': ModerationStatus.resolved.name},
        );
      case 'database:user_rewards:active_count':
        final pipeline = _queryBuilder.buildPipelineForMetric(
          query,
          startDate,
          now,
        );
        if (pipeline == null) return 0;

        final result = await _aggregate(
          _userRewardsRepository,
          pipeline: pipeline,
        );
        return result.firstOrNull?['total'] as num? ?? 0;
      default:
        _log.warning('Unsupported database metric total: ${query.metric}');
        return 0;
    }
  }

  Future<List<DataPoint>> _getDatabaseTimeSeries(
    StandardMetricQuery query,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _log.finer(
      'Executing database time series query for: ${query.metric}',
    );
    final pipeline = _queryBuilder.buildPipelineForMetric(
      query,
      startDate,
      endDate,
    );

    if (pipeline == null) {
      _log.warning('No pipeline for database time series: ${query.metric}');
      return [];
    }

    // Determine the correct repository based on the metric name.
    final repo = _getRepositoryForMetric(query.metric);
    if (repo == null) {
      _log.severe('No repository found for metric: ${query.metric}');
      return [];
    }

    final results = await _aggregate(repo, pipeline: pipeline);
    return results.map((e) {
      final label = e['label']?.toString() ?? 'Unknown';
      final value = (e['value'] as num?) ?? 0;

      final formattedLabel = label
          .split(' ')
          .map((word) {
            if (word.isEmpty) return '';
            return '${word[0].toUpperCase()}${word.substring(1)}';
          })
          .join(' ');
      return DataPoint(label: formattedLabel, value: value);
    }).toList();
  }

  Future<List<RankedListItem>> _getDatabaseRankedList(
    StandardMetricQuery query,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _log.finer(
      'Executing database ranked list query for: ${query.metric}',
    );
    final pipeline = _queryBuilder.buildPipelineForMetric(
      query,
      startDate,
      endDate,
    );

    if (pipeline == null) {
      _log.warning('No pipeline for database ranked list: ${query.metric}');
      return [];
    }

    final repo = _getRepositoryForMetric(query.metric);
    if (repo == null) {
      _log.severe('No repository found for metric: ${query.metric}');
      return [];
    }

    final results = await _aggregate(repo, pipeline: pipeline);
    return results
        .map((e) {
          final entityId = (e['entityId'] as ObjectId?)?.oid;
          final displayTitle = e['displayTitle'] as String?;
          final metricValue = e['metricValue'] as num?;

          if (entityId == null || displayTitle == null || metricValue == null) {
            _log.warning('Skipping ranked list item with missing data: $e');
            return null;
          }

          return RankedListItem(
            entityId: entityId,
            displayTitle: displayTitle,
            metricValue: metricValue,
          );
        })
        .whereType<RankedListItem>()
        .toList();
  }

  DataRepository<dynamic>? _getRepositoryForMetric(String metric) {
    final parts = metric.split(':');
    if (parts.length < 2 || parts[0] != 'database') {
      _log.warning('Invalid or non-database metric format: $metric');
      return null;
    }
    final collectionName = parts[1];

    // A map for reliable, non-ambiguous repository lookup.
    final repositoryMap = <String, DataRepository<dynamic>>{
      'users': _userRepository,
      'reports': _reportRepository,
      'engagements': _engagementRepository,
      'app_reviews': _appReviewRepository,
      'sources': _sourceRepository,
      'topics': _topicRepository,
      'headlines': _headlineRepository,
      'user_rewards': _userRewardsRepository,
    };

    final repo = repositoryMap[collectionName];
    if (repo == null) {
      _log.severe(
        'No repository found for collection: "$collectionName" in metric "$metric".',
      );
    }
    return repo;
  }

  /// Calculates a metric that depends on other metrics.
  Future<num> _getCalculatedMetricTotal(
    StandardMetricQuery query,
    DateTime startDate,
    DateTime endDate,
    AnalyticsReportingClient client,
  ) async {
    _log.finer(
      'Executing calculated metric total for: ${query.metric}',
    );
    switch (query.metric) {
      case 'calculated:engagementRate':
        // Engagement Rate = (Total Reactions / Total Views) * 100
        const totalReactionsQuery = EventCountQuery(
          event: AnalyticsEvent.reactionCreated,
        );
        const totalViewsQuery = EventCountQuery(
          event: AnalyticsEvent.contentViewed,
        );

        final totalReactions = await client.getMetricTotal(
          totalReactionsQuery,
          startDate,
          endDate,
        );
        final totalViews = await client.getMetricTotal(
          totalViewsQuery,
          startDate,
          endDate,
        );

        if (totalViews == 0) return 0;
        return (totalReactions / totalViews) * 100;
      default:
        _log.warning('Unsupported calculated metric: ${query.metric}');
        return 0;
    }
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
      .replaceAll(RegExp('([A-Z])'), r' $1')
      .trim()
      .split(' ')
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
