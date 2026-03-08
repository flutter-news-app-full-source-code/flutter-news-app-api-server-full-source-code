import 'dart:async';

import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:verity_api/src/config/environment_config.dart';
import 'package:verity_api/src/models/ingestion/aggregator_type.dart';
import 'package:verity_api/src/models/ingestion/ingestion_topic_mapping.dart';
import 'package:verity_api/src/services/idempotency_service.dart';
import 'package:verity_api/src/services/ingestion/registries/aggregator_registry.dart';

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
    required DataRepository<Topic> topicRepository,
    required DataRepository<Country> countryRepository,
    required DataRepository<IngestionTopicMapping> mappingRepository,
    required AggregatorRegistry aggregatorRegistry,
    required IdempotencyService idempotencyService,
    required Logger log,
  }) : _taskRepository = taskRepository,
       _headlineRepository = headlineRepository,
       _sourceRepository = sourceRepository,
       _topicRepository = topicRepository,
       _countryRepository = countryRepository,
       _mappingRepository = mappingRepository,
       _aggregatorRegistry = aggregatorRegistry,
       _idempotencyService = idempotencyService,
       _log = log;

  final DataRepository<NewsAutomationTask> _taskRepository;
  final DataRepository<Headline> _headlineRepository;
  final DataRepository<Source> _sourceRepository;
  final DataRepository<Topic> _topicRepository;
  final DataRepository<Country> _countryRepository;
  final DataRepository<IngestionTopicMapping> _mappingRepository;
  final AggregatorRegistry _aggregatorRegistry;
  final IdempotencyService _idempotencyService;
  final Logger _log;

  /// Polls for pending tasks and executes them.
  ///
  /// This is the main entry point for the Cron worker.
  Future<void> run() async {
    _log.info('Starting ingestion cycle...');
    try {
      // 1. Warm up Caches: Fetch metadata once per run for O(1) resolution.
      // Limit set to 300 per recommendation.
      final topics = await _topicRepository.readAll(
        pagination: const PaginationOptions(limit: 300),
      );
      final countries = await _countryRepository.readAll(
        pagination: const PaginationOptions(limit: 300),
      );
      final mappings = await _mappingRepository.readAll(
        pagination: const PaginationOptions(limit: 300),
      );

      if (topics.hasMore || countries.hasMore || mappings.hasMore) {
        _log.warning('Metadata cache is incomplete (limit reached).');
      }

      final topicCache = {for (final t in topics.items) t.id: t};
      final countryCache = {
        for (final c in countries.items) c.isoCode.toLowerCase(): c,
      };

      // Build provider-specific mapping maps: Map<Provider, Map<External, ID>>
      final mappingCache = <AggregatorType, Map<String, String>>{};
      for (final m in mappings.items) {
        mappingCache.putIfAbsent(
          m.provider,
          () => {},
        )[m.externalValue.toLowerCase()] = m.internalTopicId;
      }

      // 2. Claim Tasks
      final tasks = await _claimPendingTasks();
      _log.info('Claimed ${tasks.length} tasks for processing.');

      for (final task in tasks) {
        await _processTask(task, topicCache, countryCache, mappingCache);
      }
    } catch (e, s) {
      _log.severe('Critical failure in ingestion cycle.', e, s);
    }
  }

  Future<List<NewsAutomationTask>> _claimPendingTasks() async {
    final now = DateTime.now().toUtc();

    // Find tasks that are due.
    final response = await _taskRepository.readAll(
      filter: {
        'status': IngestionStatus.active.name,
        'nextRunAt': {r'$lte': now.toIso8601String()},
      },
    );

    final claimed = <NewsAutomationTask>[];

    for (final task in response.items) {
      // Atomic Lock: Use a windowed key (e.g. task_id + 15min_slot)
      // This ensures only one worker instance processes this task in this window.
      final window = now.millisecondsSinceEpoch ~/ (1000 * 60 * 15);
      final lockKey = 'lock:task:${task.id}:$window';

      try {
        await _idempotencyService.recordEvent(lockKey, scope: 'ingestion_lock');
        claimed.add(task);
      } on ConflictException {
        _log.info('Task ${task.id} already claimed by another worker.');
        continue;
      }
    }

    return claimed;
  }

  Future<void> _processTask(
    NewsAutomationTask task,
    Map<String, Topic> topicCache,
    Map<String, Country> countryCache,
    Map<AggregatorType, Map<String, String>> mappingCache,
  ) async {
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

      final headlines = await provider.fetchLatestHeadlines(
        source,
        topicCache: topicCache,
        countryCache: countryCache,
        // Pass only the relevant mapping for this provider
        mappingCache: mappingCache[providerType] ?? {},
      );
      _log.info('Fetched ${headlines.length} headlines from aggregator.');

      var savedCount = 0;
      var skippedCount = 0;

      for (final raw in headlines) {
        // 3. Deduplication

        final isDuplicate = await _idempotencyService.isDuplicate(
          'headline_ingestion',
          '${raw.source.id}:${raw.url}',
        );

        if (isDuplicate) {
          skippedCount++;
          continue;
        }

        final processed = raw;

        // --- TODO(fulleni): Multi-language Title AI Translation ---
        // Invoke TranslationService to fill processed.title for other languages.

        // --- TODO(fulleni): AI content enrichement ---
        // 1. Use AI to extract actual eventCountry from title/description.
        // 2. Use AI to determine if isBreaking should be true.
        // 3. Use AI to refine Topic if the provider mapping is too generic.

        // 4. Persistence
        await _headlineRepository.create(item: processed);

        await _idempotencyService.recordEvent(
          '${raw.source.id}:${raw.url}',
          scope: 'headline_ingestion',
        );

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

    // Exponential Backoff: base_interval * 2^failures
    final baseInterval = _getIntervalDuration(task.fetchInterval);
    final multiplier = success ? 1 : (1 << task.failureCount.clamp(0, 6));
    final nextRun = now.add(baseInterval * multiplier);

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
