import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// {@template applovin_reward_callback}
/// Represents the parsed and validated payload from an AppLovin MAX S2S callback.
/// {@endtemplate}
class AppLovinRewardCallback extends Equatable {
  /// {@macro applovin_reward_callback}
  const AppLovinRewardCallback({
    required this.eventId,
    required this.userId,
    required this.timestamp,
    required this.signature,
    required this.rewardItem,
  });

  /// Factory to create a callback object from a URI.
  factory AppLovinRewardCallback.fromUri(Uri uri) {
    final params = uri.queryParameters;

    final eventId = params['event_id'];
    final userId = params['user_id'];
    final ts = params['ts'];
    final signature = params['signature'];
    // AppLovin allows passing custom parameters. We expect the client to pass
    // the reward type in a parameter named 'reward_type' or 'custom_data'.
    final rewardItem = params['reward_type'] ?? params['custom_data'];

    if (eventId == null || eventId.isEmpty) {
      throw const InvalidInputException('Missing event_id');
    }
    if (userId == null || userId.isEmpty) {
      throw const InvalidInputException('Missing user_id');
    }
    if (ts == null || ts.isEmpty) {
      throw const InvalidInputException('Missing ts');
    }
    if (signature == null || signature.isEmpty) {
      throw const InvalidInputException('Missing signature');
    }
    if (rewardItem == null || rewardItem.isEmpty) {
      throw const InvalidInputException('Missing reward_type/custom_data');
    }

    return AppLovinRewardCallback(
      eventId: eventId,
      userId: userId,
      timestamp: ts,
      signature: signature,
      rewardItem: rewardItem,
    );
  }

  /// Unique event ID from AppLovin.
  final String eventId;

  /// The user ID to whom the reward should be granted.
  final String userId;

  /// The timestamp of the event.
  final String timestamp;

  /// The cryptographic signature used to verify the request.
  final String signature;

  /// The type of reward to grant (e.g., 'adFree').
  final String rewardItem;

  @override
  List<Object?> get props => [
    eventId,
    userId,
    timestamp,
    signature,
    rewardItem,
  ];
}
