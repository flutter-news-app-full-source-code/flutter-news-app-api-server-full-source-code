import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// {@template verified_reward_payload}
/// A normalized data object representing a successfully verified reward
/// from any ad provider (AdMob, AppLovin, etc.).
/// {@endtemplate}
class VerifiedRewardPayload extends Equatable {
  /// {@macro verified_reward_payload}
  const VerifiedRewardPayload({
    required this.transactionId,
    required this.userId,
    required this.rewardType,
  });

  /// The unique transaction ID from the provider (e.g., AdMob transaction_id, AppLovin event_id).
  final String transactionId;

  /// The user ID to whom the reward should be granted.
  final String userId;

  /// The type of reward to grant.
  final RewardType rewardType;

  @override
  List<Object?> get props => [transactionId, userId, rewardType];
}
