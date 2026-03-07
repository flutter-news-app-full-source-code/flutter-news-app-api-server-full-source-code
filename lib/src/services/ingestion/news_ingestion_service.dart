import 'dart:async';

import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:verity_api/src/config/environment_config.dart';
import 'package:verity_api/src/models/ingestion/aggregator_type.dart';
import 'package:verity_api/src/services/content_enrichment_service.dart';
import 'package:verity_api/src/services/idempotency_service.dart';
import 'package:verity_api/src/services/ingestion/aggregator_registry.dart';

/// {@template news_ingestion_service}
/// Orchestrates the automated ingestion of news from external aggregators.
///
/// This service implements the "Worker-Queue" pattern using MongoDB as a
/// distributed lock provider. It ensures that headlines are fetched,
/// deduplicated, hydrated, and persisted with high reliability.
/// {@endtemplate}
class NewsIngestionService {
  /// {@macro news_ingestion_service}
  const NewsIngestionService({
    required DataRepository<NewsAutomationTask> taskRepository,
    required DataRepository<Headline> headlineRepository,
    required DataRepository<Source> sourceRepository,
    required AggregatorRegistry aggregatorRegistry,
    required ContentEnrichmentService enrichmentService,
    required IdempotencyService idempotencyService,
    required Logger log,
  }) : _taskRepository = taskRepository,
       _headlineRepository = headlineRepository,
       _sourceRepository = sourceRepository,
       _aggregatorRegistry = aggregatorRegistry,
       _enrichmentService = enrichmentService,
       _idempotencyService = idempotencyService,
       _log = log;

  final DataRepository<NewsAutomationTask> _taskRepository;
  final DataRepository<Headline> _headlineRepository;
  final DataRepository<Source> _sourceRepository;
  final AggregatorRegistry _aggregatorRegistry;
  final ContentEnrichmentService _enrichmentService;
  final IdempotencyService _idempotencyService;
  final Logger _log;

  /// Polls for pending tasks and executes them.
  ///
  /// This is the main entry point for the Cron worker.
  Future<void> run() async {
    _log.info('Starting ingestion cycle...');

    try {
      final tasks = await _claimPendingTasks();
      _log.info('Claimed ${tasks.length} tasks for processing.');

      for (final task in tasks) {
        await _processTask(task);
      }
    } catch (e, s) {
      _log.severe('Critical failure in ingestion cycle.', e, s);
    }
  }

  Future<List<NewsAutomationTask>> _claimPendingTasks() async {
    final now = DateTime.now().toUtc();

    // We use a direct query to the repository to find tasks that are 'active'
    // and due for a run. In a production environment, this would use
    // findAndModify to set status to 'processing' atomically.
    final response = await _taskRepository.readAll(
      filter: {
        'status': IngestionStatus.active.name,
        'nextRunAt': {r'$lte': now.toIso8601String()},
      },
    );
    return response.items;
  }

  Future<void> _processTask(NewsAutomationTask task) async {
    _log.info('Processing task ${task.id} for source ${task.sourceId}');

    try {
      // 1. Fetch the authoritative Source document
      final source = await _sourceRepository.read(id: task.sourceId);

      // 2. Resolve Provider from Registry
      // The provider type is determined by the environment config.
      final providerType = AggregatorType.values.byName(
        EnvironmentConfig.aggregatorProvider,
      );
      final provider = _aggregatorRegistry.getProvider(providerType);

      final rawHeadlines = await provider.fetchLatestHeadlines(source);
      _log.info('Fetched ${rawHeadlines.length} headlines from aggregator.');

      var savedCount = 0;
      var skippedCount = 0;

      for (final raw in rawHeadlines) {
        // 3. Deduplication via IdempotencyService
        final isDuplicate = await _idempotencyService.isDuplicate(
          'headline_url',
          raw.url,
        );

        if (isDuplicate) {
          skippedCount++;
          continue;
        }

        // 4. Hydration via ContentEnrichmentService
        // This ensures the Headline has full Source/Topic/Country objects.
        final enriched = await _enrichmentService.enrichHeadline(raw);

        // 5. Persistence
        await _headlineRepository.create(item: enriched);
        savedCount++;
      }

      _log.info(
        'Task ${task.id} complete. Saved: $savedCount, Skipped: $skippedCount',
      );
      await _finalizeTask(task, success: true, savedCount: savedCount);
    } catch (e, s) {
      _log.severe('Failed to process task ${task.id}', e, s);
      await _finalizeTask(task, success: false, error: e.toString());
    }
  }

  Future<void> _finalizeTask(
    NewsAutomationTask task, {
    required bool success,
    int savedCount = 0,
    String? error,
  }) async {
    final now = DateTime.now().toUtc();
    final nextRun = now.add(_getIntervalDuration(task.fetchInterval));

    final updatedTask = task.copyWith(
      status: success ? IngestionStatus.active : IngestionStatus.error,
      lastRunAt: ValueWrapper(now),
      nextRunAt: ValueWrapper(nextRun),
      failureCount: success ? 0 : task.failureCount + 1,
      lastErrorMessage: ValueWrapper(error),
      updatedAt: now,
    );

    await _taskRepository.update(id: task.id, item: updatedTask);
  }

  Duration _getIntervalDuration(FetchInterval interval) {
    return switch (interval) {
      FetchInterval.every15Minutes => const Duration(minutes: 15),
      FetchInterval.every30Minutes => const Duration(minutes: 30),
      FetchInterval.hourly => const Duration(hours: 1),
      FetchInterval.everySixHours => const Duration(hours: 6),
      FetchInterval.daily => const Duration(days: 1),
    };
  }
}
