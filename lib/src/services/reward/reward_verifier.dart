import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/reward/verified_reward_payload.dart';

/// {@template reward_verifier}
/// Defines the contract for verifying reward callbacks from different providers.
/// {@endtemplate}
abstract class RewardVerifier {
  /// Verifies the incoming request URI and returns a normalized payload.
  ///
  /// Throws [InvalidInputException] or [ForbiddenException] on failure.
  Future<VerifiedRewardPayload> verify(Uri uri);
}
