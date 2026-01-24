import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// {@template admob_reward_callback}
/// Represents the parsed and validated payload from an AdMob SSV callback.
/// {@endtemplate}
class AdMobRewardCallback extends Equatable {
  /// {@macro admob_reward_callback}
  const AdMobRewardCallback({
    required this.transactionId,
    required this.userId,
    required this.rewardItem,
    required this.rewardAmount,
    required this.signature,
    required this.keyId,
    required this.originalUri,
  });

  /// Factory to create a callback object from a URI.
  ///
  /// Throws [InvalidInputException] if required fields are missing.
  factory AdMobRewardCallback.fromUri(Uri uri) {
    final params = uri.queryParameters;

    final transactionId = params['transaction_id'];
    final userId = params['user_id'];
    // We map the 'custom_data' param (from client) to the 'rewardItem' field.
    // This allows the client to dynamically specify the reward type.
    final rewardItem = params['custom_data'];
    final rewardAmountStr = params['reward_amount'];
    final signature = params['signature'];
    final keyId = params['key_id'];

    if (transactionId == null || transactionId.isEmpty) {
      throw const InvalidInputException('Missing transaction_id');
    }
    if (userId == null || userId.isEmpty) {
      throw const InvalidInputException('Missing user_id');
    }
    if (rewardItem == null || rewardItem.isEmpty) {
      throw const InvalidInputException('Missing custom_data (rewardItem)');
    }
    if (signature == null || signature.isEmpty) {
      throw const InvalidInputException('Missing signature');
    }
    if (keyId == null || keyId.isEmpty) {
      throw const InvalidInputException('Missing key_id');
    }

    // Parse reward amount, defaulting to 1 if missing or invalid.
    var rewardAmount = 1;
    if (rewardAmountStr != null) {
      rewardAmount = int.tryParse(rewardAmountStr) ?? 1;
    }

    return AdMobRewardCallback(
      transactionId: transactionId,
      userId: userId,
      rewardItem: rewardItem,
      rewardAmount: rewardAmount,
      signature: signature,
      keyId: keyId,
      originalUri: uri,
    );
  }

  /// Unique transaction ID from AdMob.
  final String transactionId;

  /// The user ID who watched the ad (passed via user_id).
  final String userId;

  /// The type of reward (e.g., "adFree"), mapped from 'custom_data'.
  final String rewardItem;

  /// The amount of the reward specified in the AdMob console.
  ///
  /// **Architecture Note:** This value is parsed for logging and validation
  /// purposes but is **ignored** by the `RewardsService` for duration
  /// calculations. The `RemoteConfig` is the single source of truth for
  /// reward value/duration.
  final int rewardAmount;

  /// The cryptographic signature.
  final String signature;

  /// The ID of the key used to sign the request.
  final String keyId;

  /// The original URI, required for signature verification reconstruction.
  final Uri originalUri;

  @override
  List<Object?> get props => [
    transactionId,
    userId,
    rewardItem,
    rewardAmount,
    signature,
    keyId,
    originalUri,
  ];
}
