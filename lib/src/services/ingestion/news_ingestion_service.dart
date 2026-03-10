import 'dart:async';
import 'dart:convert';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:verity_api/src/config/environment_config.dart';
import 'package:verity_api/src/models/ingestion/aggregator_catalog_source.dart';
import 'package:verity_api/src/models/ingestion/aggregator_source_mapping.dart';
import 'package:verity_api/src/models/ingestion/aggregator_type.dart';
import 'package:verity_api/src/models/ingestion/ingestion_topic_mapping.dart';
import 'package:verity_api/src/models/ingestion/ingestion_usage.dart';
import 'package:verity_api/src/services/idempotency_service.dart';
import 'package:verity_api/src/services/ingestion/providers/aggregator_provider.dart';

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
    required DataRepository<AggregatorSourceMapping> sourceMappingRepository,
    required DataRepository<IngestionUsage> usageRepository,
    required AggregatorProvider provider,
    required IdempotencyService idempotencyService,
    required Logger log,
  }) : _taskRepository = taskRepository,
       _headlineRepository = headlineRepository,
       _sourceRepository = sourceRepository,
       _topicRepository = topicRepository,
       _countryRepository = countryRepository,
       _mappingRepository = mappingRepository,
       _sourceMappingRepository = sourceMappingRepository,
       _usageRepository = usageRepository,
       _provider = provider,
       _idempotencyService = idempotencyService,
       _log = log;

  final DataRepository<NewsAutomationTask> _taskRepository;
  final DataRepository<Headline> _headlineRepository;
  final DataRepository<Source> _sourceRepository;
  final DataRepository<Topic> _topicRepository;
  final DataRepository<Country> _countryRepository;
  final DataRepository<IngestionTopicMapping> _mappingRepository;
  final DataRepository<AggregatorSourceMapping> _sourceMappingRepository;
  final DataRepository<IngestionUsage> _usageRepository;
  final AggregatorProvider _provider;
  final IdempotencyService _idempotencyService;
  final Logger _log;

  /// Polls for pending tasks and executes them.
  ///
  /// This is the main entry point for the Cron worker.
  Future<void> run() async {
    _log.info('Starting ingestion cycle...');
    try {
      // 0. Check Daily Quota (Cost Control)
      final isQuotaExceeded = await _checkAndLogQuota();
      if (isQuotaExceeded) {
        _log.warning(
          'Daily ingestion quota exceeded. Aborting cycle to prevent overage.',
        );
        return;
      }

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

      // Resolve Fallback Topic (Safe Default)
      // We try to find 'General' or 'World', otherwise take the first available.
      final fallbackTopic = topicCache.values.firstWhere(
        (t) => t.name[SupportedLanguage.en] == 'General',
        orElse: () => topicCache.values.first,
      );

      // Build provider-specific mapping maps: Map<Provider, Map<External, ID>>
      final mappingCache = <AggregatorType, Map<String, String>>{};
      for (final m in mappings.items) {
        mappingCache.putIfAbsent(
          m.provider,
          () => {},
        )[m.externalValue.toLowerCase()] = m.internalTopicId;
      }

      // 2. Claim Due Tasks
      final tasks = await _claimPendingTasks();
      _log.info('Claimed ${tasks.length} tasks for processing.');
      if (tasks.isEmpty) return;

      // 3. Group Tasks by Provider
      final providerType = AggregatorType.values.byName(
        EnvironmentConfig.aggregatorProvider,
      );

      // Phase 1: Discovery & Mapping
      // Ensure all claimed tasks have a valid provider mapping.
      final validMappings = await _ensureMappings(tasks, providerType);
      _log.info('Discovery complete. ${validMappings.length} sources mapped.');

      if (validMappings.isEmpty) {
        _log.warning('No valid mappings found for this cycle.');
        return;
      }

      // Phase 2: Batch Fetching
      // Execute the N:1 request and attribute results.
      await _executeProviderBatch(
        validMappings,
        tasks,
        providerType,
        topicCache,
        fallbackTopic,
        countryCache,
        mappingCache,
      );
    } catch (e, s) {
      _log.severe('Critical failure in ingestion cycle.', e, s);
    }
  }

  /// Phase 1: Discovery
  /// Checks the database for existing mappings. If missing, triggers on-demand
  /// catalog sync from the provider and performs host-based matching.
  Future<List<AggregatorSourceMapping>> _ensureMappings(
    List<NewsAutomationTask> tasks,
    AggregatorType providerType,
  ) async {
    final results = <AggregatorSourceMapping>[];
    List<AggregatorCatalogSource>? catalog;

    for (final task in tasks) {
      try {
        // 1. Check DB for existing mapping
        final existing = await _sourceMappingRepository.readAll(
          filter: {
            'sourceId': task.sourceId,
            'aggregatorType': providerType.name,
            'isEnabled': true,
          },
        );

        if (existing.items.isNotEmpty) {
          results.add(existing.items.first);
          continue;
        }

        // 2. Missing Mapping: Trigger On-Demand Discovery
        _log.info(
          'Mapping missing for source ${task.sourceId}. Discovering...',
        );
        catalog ??= await _provider.syncCatalog();

        final source = await _sourceRepository.read(id: task.sourceId);
        final sourceHost = Uri.parse(source.url).host.replaceFirst('www.', '');

        // Match by URL host (deterministic)
        final match = catalog.firstWhere(
          (s) =>
              s.url != null &&
              Uri.parse(s.url!).host.replaceFirst('www.', '') == sourceHost,
          orElse: () => throw const NotFoundException('Source not in catalog'),
        );

        // 3. Persist Mapping
        final mapping = AggregatorSourceMapping(
          id: ObjectId().oid,
          sourceId: task.sourceId,
          aggregatorType: providerType,
          externalId: match.externalId,
          createdAt: DateTime.now(),
        );
        await _sourceMappingRepository.create(item: mapping);
        results.add(mapping);
      } on NotFoundException {
        _log.warning('Source ${task.sourceId} not supported by $providerType');
        await _finalizeTask(
          task,
          success: false,
          error: 'Source not supported by provider catalog.',
        );
      } catch (e, s) {
        _log.severe('Discovery error for task ${task.id}', e, s);
      }
    }
    return results;
  }

  /// Phase 2: Batch Fetching
  /// Orchestrates the N:1 request and handles the "Poison Pill" fallback.
  Future<void> _executeProviderBatch(
    List<AggregatorSourceMapping> mappings,
    List<NewsAutomationTask> tasks,
    AggregatorType providerType,
    Map<String, Topic> topicCache,
    Topic fallbackTopic,
    Map<String, Country> countryCache,
    Map<AggregatorType, Map<String, String>> mappingCache,
  ) async {
    // Fetch full Source entities for mapping context
    final sourceIds = mappings.map((m) => m.sourceId).toSet();
    final sourceResponse = await _sourceRepository.readAll(
      filter: {
        '_id': {r'$in': sourceIds.toList()},
      },
    );
    final sourceMap = {for (final s in sourceResponse.items) s.id: s};

    try {
      // Execute the Batch Request
      final batchResults = await _provider.fetchBatchHeadlines(
        mappings,
        sourceMap: sourceMap,
        topicCache: topicCache,
        fallbackTopic: fallbackTopic,
        countryCache: countryCache,
        mappingCache: mappingCache[providerType] ?? {},
      );

      await _incrementQuota();

      // Process results for each source in the batch
      for (final mapping in mappings) {
        final task = tasks.firstWhere((t) => t.sourceId == mapping.sourceId);
        final headlines = batchResults[mapping.sourceId] ?? [];

        await _processHeadlines(headlines, task);
      }
    } on BadRequestException {
      _log.warning(
        'Batch failed with 400. Initiating poison pill isolation...',
      );
      await _isolatePoisonPill(
        mappings,
        tasks,
        providerType,
        sourceMap,
        topicCache,
        fallbackTopic,
        countryCache,
        mappingCache,
      );
    } catch (e, s) {
      _log.severe('Critical batch failure.', e, s);
      // Mark all tasks in this batch as failed
      for (final mapping in mappings) {
        final task = tasks.firstWhere((t) => t.sourceId == mapping.sourceId);
        await _finalizeTask(task, success: false, error: e.toString());
      }
    }
  }

  /// The "De-batching Fallback"
  /// Executes 1:1 requests to identify which source is causing the 400 error.
  Future<void> _isolatePoisonPill(
    List<AggregatorSourceMapping> mappings,
    List<NewsAutomationTask> tasks,
    AggregatorType providerType,
    Map<String, Source> sourceMap,
    Map<String, Topic> topicCache,
    Topic fallbackTopic,
    Map<String, Country> countryCache,
    Map<AggregatorType, Map<String, String>> mappingCache,
  ) async {
    for (final mapping in mappings) {
      final task = tasks.firstWhere((t) => t.sourceId == mapping.sourceId);

      try {
        // Execute 1:1 fetch
        final results = await _provider.fetchBatchHeadlines(
          [mapping],
          sourceMap: sourceMap,
          topicCache: topicCache,
          fallbackTopic: fallbackTopic,
          countryCache: countryCache,
          mappingCache: mappingCache[providerType] ?? {},
        );

        await _incrementQuota();
        await _processHeadlines(results[mapping.sourceId] ?? [], task);
      } on BadRequestException {
        _log.severe('Poison pill identified: ${mapping.externalId}');
        // Disable the mapping to prevent future batch failures
        await _sourceMappingRepository.update(
          id: mapping.id,
          item: AggregatorSourceMapping(
            id: mapping.id,
            sourceId: mapping.sourceId,
            aggregatorType: mapping.aggregatorType,
            externalId: mapping.externalId,
            isEnabled: false,
            createdAt: mapping.createdAt,
          ),
        );
        await _finalizeTask(
          task,
          success: false,
          error: 'Source rejected by provider.',
        );
      } catch (e) {
        await _finalizeTask(task, success: false, error: e.toString());
      }
    }
  }

  Future<void> _processHeadlines(
    List<Headline> headlines,
    NewsAutomationTask task,
  ) async {
    var savedCount = 0;
    var skippedCount = 0;
    var errorCount = 0;

    for (final raw in headlines) {
      try {
        final isDuplicate = await _idempotencyService.isDuplicate(
          'headline_ingestion',
          '${raw.source.id}:${raw.url}',
        );

        if (isDuplicate) {
          skippedCount++;
          continue;
        }

        await _headlineRepository.create(item: raw);
        await _idempotencyService.recordEvent(
          '${raw.source.id}:${raw.url}',
          scope: 'headline_ingestion',
        );
        savedCount++;
      } catch (e, s) {
        _log.warning('Failed to save headline: ${raw.url}', e, s);
        errorCount++;
      }
    }

    final isSuccess = errorCount == 0 || savedCount > 0 || skippedCount > 0;
    await _finalizeTask(
      task,
      success: isSuccess,
      savedCount: savedCount,
      error: isSuccess ? null : 'Batch processing failed.',
    );
  }

  Future<List<NewsAutomationTask>> _claimPendingTasks() async {
    final now = DateTime.now().toUtc();

    // Find tasks that are due.
    final response = await _taskRepository.readAll(
      filter: {
        'status': IngestionStatus.active.name,
        r'$or': [
          {
            // Use ISO-8601 String for query to match the String type stored in MongoDB.
            // Direct DateTime objects would be serialized as BSON Dates, causing a type mismatch.
            'nextRunAt': {r'$lte': now.toIso8601String()},
          },
          {'nextRunAt': null},
          {
            'nextRunAt': {r'$exists': false},
          },
        ],
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

  /// Checks if the daily quota has been reached.
  /// Returns `true` if quota is exceeded, `false` otherwise.
  Future<bool> _checkAndLogQuota() async {
    final now = DateTime.now().toUtc();
    final todayId = _getUsageId(now);
    final limit = EnvironmentConfig.ingestionDailyQuota;

    try {
      final usage = await _usageRepository.read(id: todayId);
      _log.info('Daily Usage: ${usage.requestCount} / $limit');
      return usage.requestCount >= limit;
    } on NotFoundException {
      // No record for today means usage is 0.
      return false;
    } catch (e) {
      _log.warning('Failed to check quota. Assuming safe to proceed.', e);
      return false;
    }
  }

  /// Increments the daily usage count.
  Future<void> _incrementQuota() async {
    final now = DateTime.now().toUtc();
    final todayId = _getUsageId(now);

    try {
      final usage = await _usageRepository.read(id: todayId);
      await _usageRepository.update(
        id: todayId,
        item: IngestionUsage(
          id: todayId,
          requestCount: usage.requestCount + 1,
          updatedAt: now,
        ),
      );
    } on NotFoundException {
      await _usageRepository.create(
        item: IngestionUsage(id: todayId, requestCount: 1, updatedAt: now),
      );
    }
  }

  String _getUsageId(DateTime now) {
    // Generate a deterministic 24-character hex string for the date.
    final dateStr = '${now.year}-${now.month}-${now.day}';
    final bytes = utf8.encode('usage:$dateStr');
    return sha256.convert(bytes).toString().substring(0, 24);
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
