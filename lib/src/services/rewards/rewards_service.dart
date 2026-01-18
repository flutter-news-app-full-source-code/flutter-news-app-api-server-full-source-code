import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/payment/idempotency_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/rewards/admob_ssv_verifier.dart';
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
  /// 1. Verifies the cryptographic signature.
  /// 2. Checks idempotency using the transaction ID.
  /// 3. Grants the reward to the user.
  ///
  /// [uri] is the full request URI containing the query parameters.
  Future<void> processAdMobCallback(Uri uri) async {
    _log.info('Processing AdMob reward callback.');

    // 1. Verify Signature
    await _admobVerifier.verify(uri);

    // 2. Extract Data
    final queryParams = uri.queryParameters;
    final userId = queryParams['custom_data']; // We send userId in custom_data
    final rewardItem = queryParams['reward_item']; // e.g., "adFree"
    final transactionId = queryParams['transaction_id'];
    final rewardAmountStr = queryParams['reward_amount'];

    if (userId == null || rewardItem == null || transactionId == null) {
      _log.warning('Missing required fields in AdMob callback.');
      throw const InvalidInputException('Missing required fields.');
    }

    // 3. Idempotency Check
    if (await _idempotencyService.isEventProcessed(transactionId)) {
      _log.info('Reward transaction $transactionId already processed.');
      return;
    }

    // 4. Map Reward Item to RewardType
    // We assume the Ad Unit is configured to send the RewardType name (e.g. "adFree")
    // as the "Reward Item" string.
    final rewardType = RewardType.values.asNameMap()[rewardItem];
    if (rewardType == null) {
      _log.warning('Unknown reward type received: $rewardItem');
      throw const BadRequestException('Unknown reward type.');
    }

    // 5. Parse Reward Amount
    // The reward amount is used as a multiplier for the base duration.
    // Default to 1 if missing or invalid.
    var multiplier = 1;
    if (rewardAmountStr != null) {
      final parsed = int.tryParse(rewardAmountStr);
      if (parsed != null && parsed > 0) {
        multiplier = parsed;
      }
    }

    // 6. Grant Reward
    await _grantReward(
      userId: userId,
      rewardType: rewardType,
      transactionId: transactionId,
      multiplier: multiplier,
    );

    _log.info('Successfully granted $rewardType to user $userId.');
  }

  /// Grants a specific reward to a user.
  ///
  /// This method handles the logic of extending an existing reward or starting
  /// a new one based on the configuration.
  Future<void> _grantReward({
    required String userId,
    required RewardType rewardType,
    required String transactionId,
    required int multiplier,
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
    UserRewards userRewards;
    try {
      userRewards = await _userRewardsRepository.read(id: userId);
    } on NotFoundException {
      userRewards = UserRewards(
        id: userId,
        userId: userId,
        activeRewards: {},
      );
    }

    // Calculate New Expiration
    final now = DateTime.now();
    final currentExpiry = userRewards.activeRewards[rewardType] ?? now;

    // If expired, start from now. If active, extend from current expiry.
    final effectiveStartTime =
        currentExpiry.isBefore(now) ? now : currentExpiry;
    final durationToAdd = Duration(
      days: rewardDetails.durationDays * multiplier,
    );
    final newExpiry = effectiveStartTime.add(durationToAdd);

    // Update & Persist
    final updatedRewardsMap = Map<RewardType, DateTime>.from(
      userRewards.activeRewards,
    );
    updatedRewardsMap[rewardType] = newExpiry;

    final updatedUserRewards = userRewards.copyWith(
      activeRewards: updatedRewardsMap,
    );

    if (userRewards.activeRewards.isEmpty) {
      // If it was a new/empty object, we might need to create it.
      // However, since we use `read` above which throws NotFound,
      // we can rely on the repository's update/create semantics.
      // For safety with the generic repo, we try update, fallback to create.
      try {
        await _userRewardsRepository.update(
          id: userId,
          item: updatedUserRewards,
        );
      } on NotFoundException {
        await _userRewardsRepository.create(item: updatedUserRewards);
      }
    } else {
      await _userRewardsRepository.update(id: userId, item: updatedUserRewards);
    }

    // Record Idempotency
    await _idempotencyService.recordEvent(transactionId);
  }
}
