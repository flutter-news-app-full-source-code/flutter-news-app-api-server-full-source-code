import 'dart:convert';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:verity_api/src/clients/intelligence/intelligence_client.dart';
import 'package:verity_api/src/config/environment_config.dart';
import 'package:verity_api/src/models/intelligence/ai_usage.dart';
import 'package:verity_api/src/services/intelligence/strategies/ai_strategy.dart';

/// {@template intelligence_service}
/// Orchestrates all AI-powered operations with strict token governance.
///
/// This service uses the Strategy pattern to handle diverse AI tasks
/// (Ingestion, Summarization, etc.) while centralizing the cost-control
/// logic and token quota management.
/// {@endtemplate}
class IntelligenceService {
  /// {@macro intelligence_service}
  IntelligenceService({
    required IntelligenceClient client,
    required DataRepository<AiUsage> usageRepository,
    required DataRepository<Topic> topicRepository,
    required DataRepository<RemoteConfig> remoteConfigRepository,
    required Logger log,
  }) : _client = client,
       _usageRepository = usageRepository,
       _topicRepository = topicRepository,
       _remoteConfigRepository = remoteConfigRepository,
       _log = log;

  final IntelligenceClient _client;
  final DataRepository<AiUsage> _usageRepository;
  final DataRepository<Topic> _topicRepository;
  final DataRepository<RemoteConfig> _remoteConfigRepository;
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
