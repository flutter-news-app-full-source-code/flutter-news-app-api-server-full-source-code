import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/idempotency_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/reward/reward_verifier.dart';
import 'package:logging/logging.dart';

/// {@template rewards_service}
/// Service responsible for managing the Time-Based Reward system.
///
/// It handles the verification of ad rewards (via SSV) and the granting of
/// entitlements (updating [UserRewards]).
/// {@endtemplate}
class RewardsService {
  /// {@macro rewards_service}
  const RewardsService({
    required DataRepository<UserRewards> userRewardsRepository,
    required DataRepository<RemoteConfig> remoteConfigRepository,
    required IdempotencyService idempotencyService,
    required Map<AdPlatformType, RewardVerifier> verifiers,
    required Logger log,
  }) : _userRewardsRepository = userRewardsRepository,
       _remoteConfigRepository = remoteConfigRepository,
       _idempotencyService = idempotencyService,
       _verifiers = verifiers,
       _log = log;

  final DataRepository<UserRewards> _userRewardsRepository;
  final DataRepository<RemoteConfig> _remoteConfigRepository;
  final IdempotencyService _idempotencyService;
  final Map<AdPlatformType, RewardVerifier> _verifiers;
  final Logger _log;

  // Assuming a fixed ID for the RemoteConfig document
  static const String _remoteConfigId = kRemoteConfigId;

  /// Processes an incoming reward callback from a specific platform.
  ///
  /// 1. Selects the appropriate verifier.
  /// 2. Verifies the signature and parses the payload.
  /// 3. Checks idempotency.
  /// 4. Grants the reward.
  Future<void> processCallback(AdPlatformType platform, Uri uri) async {
    _log.info('Processing reward callback for platform: $platform');
    final verifier = _verifiers[platform];
    if (verifier == null) {
      throw const ServerException('No verifier configured for this platform.');
    }

    // 1. Verify & Parse
    final payload = await verifier.verify(uri);

    // 2. Idempotency Check
    if (await _idempotencyService.isEventProcessed(payload.transactionId)) {
      _log.info(
        'Reward transaction ${payload.transactionId} already processed.',
      );
      return;
    }

    await _grantReward(
      userId: payload.userId,
      rewardType: payload.rewardType,
      transactionId: payload.transactionId,
    );

    _log.info(
      'Successfully granted ${payload.rewardType} to user ${payload.userId}.',
    );
  }

  /// Grants a specific reward to a user.
  ///
  /// This method handles the logic of extending an existing reward or starting
  /// a new one based on the configuration.
  Future<void> _grantReward({
    required String userId,
    required RewardType rewardType,
    required String transactionId,
  }) async {
    // Fetch Configuration
    final remoteConfig = await _remoteConfigRepository.read(
      id: _remoteConfigId,
    );
    final rewardDetails = remoteConfig.features.rewards.rewards[rewardType];

    if (rewardDetails == null || !rewardDetails.enabled) {
      _log.warning('Reward $rewardType is disabled or not configured.');
      throw const ForbiddenException('Reward is currently disabled.');
    }

    // Fetch Current User Rewards (or create default)
    UserRewards? existingRewards;
    try {
      existingRewards = await _userRewardsRepository.read(id: userId);
    } on NotFoundException {
      // It's okay if the user has no rewards document yet.
      existingRewards = null;
    }

    final userRewards =
        existingRewards ??
        UserRewards(
          id: userId,
          userId: userId,
          activeRewards: const {},
        );

    // Calculate New Expiration
    final now = DateTime.now();
    final currentExpiry = userRewards.activeRewards[rewardType] ?? now;

    // If expired, start from now. If active, extend from current expiry.
    final effectiveStartTime = currentExpiry.isBefore(now)
        ? now
        : currentExpiry;

    // Logic: Use strictly the duration defined in RemoteConfig.
    // We do NOT multiply by AdMob's rewardAmount.
    final durationToAdd = Duration(days: rewardDetails.durationDays);
    final newExpiry = effectiveStartTime.add(durationToAdd);

    // Update & Persist
    final updatedRewardsMap = Map<RewardType, DateTime>.from(
      userRewards.activeRewards,
    );
    updatedRewardsMap[rewardType] = newExpiry;

    final updatedUserRewards = userRewards.copyWith(
      activeRewards: updatedRewardsMap,
    );

    if (existingRewards == null) {
      await _userRewardsRepository.create(item: updatedUserRewards);
    } else {
      await _userRewardsRepository.update(id: userId, item: updatedUserRewards);
    }

    // Record Idempotency
    await _idempotencyService.recordEvent(transactionId);
  }
}
