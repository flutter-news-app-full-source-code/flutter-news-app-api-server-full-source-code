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
    final userId = params['custom_data']; // We map custom_data to userId
    final rewardItem = params['reward_item'];
    final rewardAmountStr = params['reward_amount'];
    final signature = params['signature'];
    final keyId = params['key_id'];

    if (transactionId == null || transactionId.isEmpty) {
      throw const InvalidInputException('Missing transaction_id');
    }
    if (userId == null || userId.isEmpty) {
      throw const InvalidInputException('Missing custom_data (userId)');
    }
    if (rewardItem == null || rewardItem.isEmpty) {
      throw const InvalidInputException('Missing reward_item');
    }
    if (signature == null || signature.isEmpty) {
      throw const InvalidInputException('Missing signature');
    }
    if (keyId == null || keyId.isEmpty) {
      throw const InvalidInputException('Missing key_id');
    }

    // Parse reward amount, defaulting to 1 if missing or invalid
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

  /// The user ID who watched the ad (passed via custom_data).
  final String userId;

  /// The type of reward (e.g., "adFree").
  final String rewardItem;

  /// The amount of the reward (multiplier).
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
