import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// {@template ironsource_reward_callback}
/// Represents the parsed and validated payload from an IronSource SSV callback.
///
/// See: https://developers.is.com/ironsource-mobile/general/serverside-rewarded-video-callbacks/
/// {@endtemplate}
class IronSourceRewardCallback extends Equatable {
  /// {@macro ironsource_reward_callback}
  const IronSourceRewardCallback({
    required this.appUserId,
    required this.rewards,
    required this.eventId,
    required this.timestamp,
    required this.signature,
  });

  /// Factory to create a callback object from a URI.
  ///
  /// Throws [InvalidInputException] if required fields are missing.
  factory IronSourceRewardCallback.fromUri(Uri uri) {
    final params = uri.queryParameters;

    final appUserId = params['appUserId'];
    final rewards = params['rewards'];
    final eventId = params['eventId'];
    final timestamp = params['timestamp'];
    final signature = params['signature'];

    if (appUserId == null || appUserId.isEmpty) {
      throw const InvalidInputException('Missing appUserId');
    }
    if (rewards == null || rewards.isEmpty) {
      throw const InvalidInputException('Missing rewards');
    }
    if (eventId == null || eventId.isEmpty) {
      throw const InvalidInputException('Missing eventId');
    }
    if (timestamp == null || timestamp.isEmpty) {
      throw const InvalidInputException('Missing timestamp');
    }
    if (signature == null || signature.isEmpty) {
      throw const InvalidInputException('Missing signature');
    }

    return IronSourceRewardCallback(
      appUserId: appUserId,
      rewards: rewards,
      eventId: eventId,
      timestamp: timestamp,
      signature: signature,
    );
  }

  /// The user ID who watched the ad.
  final String appUserId;

  /// The reward details (e.g., "10 adFree").
  final String rewards;

  /// Unique transaction ID from IronSource.
  final String eventId;

  /// The timestamp of the event.
  final String timestamp;

  /// The cryptographic signature (HMAC-SHA256).
  final String signature;

  @override
  List<Object?> get props => [
    appUserId,
    rewards,
    eventId,
    timestamp,
    signature,
  ];
}
