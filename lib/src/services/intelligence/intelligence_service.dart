import 'dart:convert';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:verity_api/src/clients/intelligence/intelligence_client.dart';
import 'package:verity_api/src/config/environment_config.dart';
import 'package:verity_api/src/models/intelligence/ai_usage.dart';
import 'package:verity_api/src/services/intelligence/batched_notification_selector.dart';
import 'package:verity_api/src/services/intelligence/identity_resolution_service.dart';
import 'package:verity_api/src/services/intelligence/strategies/ai_strategy.dart';
import 'package:verity_api/src/services/intelligence/strategies/ingestion_enrichment_strategy.dart';
import 'package:verity_api/src/services/push_notification/push_notification_service.dart';

/// {@template intelligence_service}
/// Orchestrates all AI-powered operations with strict token governance.
///
/// This service uses the Strategy pattern to handle diverse AI tasks
/// (Ingestion, Summarization, etc.) while centralizing cost-control
/// logic and token quota management.
///
/// It also acts as the controller for the background enrichment loop,
/// polling for [ContentStatus.draft] headlines and processing them.
/// {@endtemplate}
class IntelligenceService {
  /// {@macro intelligence_service}
  IntelligenceService({
    required IntelligenceClient client,
    required DataRepository<AiUsage> usageRepository,
    required DataRepository<Topic> topicRepository,
    required DataRepository<RemoteConfig> remoteConfigRepository,
    required DataRepository<Headline> headlineRepository,
    required DataRepository<Country> countryRepository,
    required IdentityResolutionService identityResolutionService,
    required IPushNotificationService pushNotificationService,
    required Logger log,
  }) : _client = client,
       _usageRepository = usageRepository,
       _topicRepository = topicRepository,
       _remoteConfigRepository = remoteConfigRepository,
       _headlineRepository = headlineRepository,
       _countryRepository = countryRepository,
       _identityResolutionService = identityResolutionService,
       _pushNotificationService = pushNotificationService,
       _log = log;

  final IntelligenceClient _client;
  final DataRepository<AiUsage> _usageRepository;
  final DataRepository<Topic> _topicRepository;
  final DataRepository<RemoteConfig> _remoteConfigRepository;
  final DataRepository<Headline> _headlineRepository;
  final DataRepository<Country> _countryRepository;
  final IdentityResolutionService _identityResolutionService;
  final IPushNotificationService _pushNotificationService;
  final Logger _log;

  /// Processes input through a specific [AiStrategy].
  ///
  /// This method performs the "Guard-Quota-Execute-Log" cycle.
  Future<TOutput> execute<TInput, TOutput>({
    required AiStrategy<TInput, TOutput> strategy,
    required TInput input,
  }) async {
    _log.finer('Executing AI strategy: ${strategy.identifier}');
    // 1. Guard: Check if AI is enabled in Environment and Quota
    if (!EnvironmentConfig.aiIngestionEnabled) {
      _log.info('AI is disabled via environment toggle. Skipping.');
      throw const OperationFailedException('AI integration is disabled.');
    }

    final now = DateTime.now().toUtc();
    final usageId = _getUsageId(now);

    // 2. Quota Check: Prevent over-spending
    _log.finer('Checking AI token quota for usage ID: $usageId');
    final currentUsage = await _getUsage(usageId);
    if (currentUsage.tokenUsage >= EnvironmentConfig.aiDailyTokenQuota) {
      _log.warning('Daily AI Token Quota exceeded ($usageId). Blocking.');
      throw const ForbiddenException('Daily AI token quota reached.');
    }
    _log.finer(
      'Quota check passed. Current usage: ${currentUsage.tokenUsage} / ${EnvironmentConfig.aiDailyTokenQuota}',
    );

    // 3. Execution: Prepare prompt with enabled languages and active topics
    _log.finer('Fetching remote config for AI prompt context...');
    final config = await _remoteConfigRepository.read(id: kRemoteConfigId);
    final enabledLangs = config.app.localization.enabledLanguages;

    // Fetch active topics to provide as a strict choice list to the AI.
    _log.finer('Fetching active topics for AI prompt context...');
    final activeTopics = await _topicRepository.readAll(
      filter: {'status': ContentStatus.active.name},
      pagination: const PaginationOptions(limit: 200),
    );
    final activeTopicNames = activeTopics.items
        .map((t) => t.name[SupportedLanguage.en] ?? t.id)
        .toList();
    _log.finer('Found ${activeTopicNames.length} active topics.');

    final inputDescription = input is List
        ? '${input.length} items'
        : input.toString().length > 50
        ? '${input.toString().substring(0, 50)}...'
        : input.toString();

    _log.info('[AI:${strategy.identifier}] Processing: $inputDescription');
    _log.finer('Building prompt for strategy: ${strategy.identifier}');
    final messages = strategy.buildPrompt(
      input,
      enabledLanguages: enabledLangs,
      predefinedChoices: activeTopicNames,
    );
    _log.finer('Prompt built. Dispatching to AI client...');

    final response = await _client.generateCompletion(messages: messages);
    _log.finer(
      'AI client responded. Tokens used: ${response.totalTokens}.',
    );

    // 4. Persistence: Update token usage
    _log.finer('Recording token usage...');
    await _recordUsage(usageId, response.totalTokens);

    // 5. Mapping: Return domain objects
    _log.finer('Mapping AI response to domain objects...');
    final output = strategy.mapResponse(response.data, input);
    _log.finer('Response mapping complete.');
    return output;
  }

  /// Executes the background enrichment cycle.
  ///
  /// Polls for headlines in [ContentStatus.draft], batches them, applies
  /// enrichment, and updates their status to [ContentStatus.active].
  Future<void> run() async {
    _log.info('Starting Intelligence enrichment cycle...');

    // 1. Calculate Batch Size
    const kEstTokensPerItem = 60;
    const kSystemPromptBuffer = 1000;
    final maxInput = EnvironmentConfig.aiMaxInputTokens;
    final batchSize = (maxInput - kSystemPromptBuffer) ~/ kEstTokensPerItem;

    _log.info(
      'Batching Configuration: MaxInput=$maxInput, BatchSize=$batchSize',
    );

    // 2. Warm up Metadata Caches
    final countryCache = <String, Country>{};
    final topicSlugMap = <String, Topic>{};

    final countries = await _countryRepository.readAll(
      pagination: const PaginationOptions(limit: 300),
    );
    for (final c in countries.items) {
      countryCache[c.isoCode.toLowerCase()] = c;
    }

    final topics = await _topicRepository.readAll(
      pagination: const PaginationOptions(limit: 300),
    );
    for (final t in topics.items) {
      topicSlugMap[t.name[SupportedLanguage.en] ?? t.id] = t;
    }

    // 3. Processing Loop
    var hasMore = true;
    String? cursor;

    while (hasMore) {
      // Polling Logic: Fetch ANY headline that hasn't been enriched yet.
      final response = await _headlineRepository.readAll(
        filter: {'lastEnrichedAt': null},
        pagination: PaginationOptions(cursor: cursor, limit: batchSize),
      );

      final drafts = response.items;
      if (drafts.isEmpty) {
        _log.info('No more drafts to process.');
        break;
      }

      _log.info('Processing batch of ${drafts.length} drafts...');

      try {
        // Execute AI Strategy
        final enrichmentMap =
            await execute<List<Headline>, Map<String, AiEnrichmentResult>>(
              strategy: IngestionEnrichmentStrategy(),
              input: drafts,
            );

        final breakingCandidates = <Headline>[];
        final breakingScores = <String, double>{};

        // Process & Update
        for (final draft in drafts) {
          final result = enrichmentMap[draft.id];

          if (result == null) {
            _log.warning(
              'No enrichment result for ${draft.id}. Skipping update.',
            );
            continue;
          }

          // 1. Junk Filter
          if (!result.isNews) {
            _log.info('Hard Deleting Junk Content: ${draft.id}');
            await _headlineRepository.delete(id: draft.id);
            continue;
          }

          // 2. Identity & Country Resolution
          final resolvedPersons = await _identityResolutionService
              .resolvePersons(result.extractedPersons);

          final resolvedCountries = <Country>[];
          for (final code in result.extractedCountryCodes) {
            final c = countryCache[code.toLowerCase()];
            if (c != null) resolvedCountries.add(c);
          }

          // 3. Topic Inference & Strict Activation
          Topic? resolvedTopic;
          if (result.topicSlug != null) {
            resolvedTopic = topicSlugMap[result.topicSlug];
          }

          // 4. Breaking News Detection
          final isBreaking = result.breakingConfidence > 0.8;

          final activeHeadline = draft.copyWith(
            status: resolvedTopic != null
                ? ContentStatus.active
                : ContentStatus.draft,
            topic: resolvedTopic ?? draft.topic,
            mentionedPersons: resolvedPersons,
            mentionedCountries: resolvedCountries,
            title: {...draft.title, ...result.translations},
            isBreaking: isBreaking,
            updatedAt: DateTime.now(),
            lastEnrichedAt: ValueWrapper(DateTime.now()),
          );

          await _headlineRepository.update(id: draft.id, item: activeHeadline);
          _log.fine('Activated headline: ${draft.id}');

          if (isBreaking) {
            breakingCandidates.add(activeHeadline);
            breakingScores[activeHeadline.id] = result.breakingConfidence;
          }
        }

        // Notify
        if (breakingCandidates.isNotEmpty) {
          final selector = BatchedNotificationSelector(
            pushNotificationService: _pushNotificationService,
            log: Logger('WorkerNotificationSelector'),
          );
          await selector.processBatch(
            candidates: breakingCandidates,
            confidenceScores: breakingScores,
          );
        }
      } catch (e, s) {
        _log.severe('Batch processing failed.', e, s);
        // Break loop on critical failure to prevent infinite error loops
        break;
      }

      cursor = null;
      hasMore = response.hasMore;
    }

    _log.info('Intelligence cycle completed.');
  }

  Future<AiUsage> _getUsage(String id) async {
    try {
      return await _usageRepository.read(id: id);
    } on NotFoundException {
      return AiUsage(
        id: id,
        tokenUsage: 0,
        requestCount: 0,
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<void> _recordUsage(String id, int tokens) async {
    final current = await _getUsage(id);
    final updated = current.copyWith(
      tokenUsage: current.tokenUsage + tokens,
      requestCount: current.requestCount + 1,
      updatedAt: DateTime.now(),
    );

    if (current.requestCount == 0) {
      await _usageRepository.create(item: updated);
    } else {
      await _usageRepository.update(id: id, item: updated);
    }

    _log.info('AI Usage Updated: ${updated.tokenUsage} tokens today.');
  }

  String _getUsageId(DateTime now) {
    // Deterministic ID for the 24h window (YYYY-MM-DD)
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final bytes = utf8.encode('ai_usage:$dateStr');
    // MongoDB objectId compatibility (24 chars)
    return sha256.convert(bytes).toString().substring(0, 24);
  }
}
