import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/reward/admob_reward_callback.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/idempotency_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/reward/admob_ssv_verifier.dart';
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
    required AdMobSsvVerifier admobVerifier,
    required Logger log,
  }) : _userRewardsRepository = userRewardsRepository,
       _remoteConfigRepository = remoteConfigRepository,
       _idempotencyService = idempotencyService,
       _admobVerifier = admobVerifier,
       _log = log;

  final DataRepository<UserRewards> _userRewardsRepository;
  final DataRepository<RemoteConfig> _remoteConfigRepository;
  final IdempotencyService _idempotencyService;
  final AdMobSsvVerifier _admobVerifier;
  final Logger _log;

  // Assuming a fixed ID for the RemoteConfig document
  static const String _remoteConfigId = kRemoteConfigId;

  /// Processes an incoming AdMob Server-Side Verification callback.
  ///
  /// 1. Parses the URI into a strongly-typed [AdMobRewardCallback].
  /// 2. Verifies the cryptographic signature.
  /// 3. Checks idempotency using the transaction ID.
  /// 4. Grants the reward to the user.
  ///
  /// [uri] is the full request URI containing the query parameters.
  Future<void> processAdMobCallback(Uri uri) async {
    _log.info('Processing AdMob reward callback.');

    // 1. Parse & Validate Input
    final callback = AdMobRewardCallback.fromUri(uri);

    // 2. Verify Signature
    await _admobVerifier.verify(callback);

    // 3. Idempotency Check
    if (await _idempotencyService.isEventProcessed(callback.transactionId)) {
      _log.info(
        'Reward transaction ${callback.transactionId} already processed.',
      );
      return;
    }

    // 4. Map Reward Item to RewardType
    final rewardType = RewardType.values.asNameMap()[callback.rewardItem];
    if (rewardType == null) {
      _log.warning('Unknown reward type received: ${callback.rewardItem}');
      throw const BadRequestException('Unknown reward type.');
    }

    // 5. Grant Reward
    // Note: We intentionally ignore `callback.rewardAmount` for the duration
    // calculation to enforce RemoteConfig as the single source of truth.
    await _grantReward(
      userId: callback.userId,
      rewardType: rewardType,
      transactionId: callback.transactionId,
    );

    _log.info(
      'Successfully granted $rewardType to user ${callback.userId}.',
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
