import 'dart:convert';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/reward/applovin_reward_callback.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/reward/verified_reward_payload.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/reward/reward_verifier.dart';
import 'package:logging/logging.dart';

/// {@template applovin_ssv_verifier}
/// Verifies Server-Side Verification (SSV) callbacks from AppLovin MAX.
///
/// Uses an MD5 hash of the parameters + secret key to verify authenticity.
/// {@endtemplate}
class AppLovinSsvVerifier implements RewardVerifier {
  /// {@macro applovin_ssv_verifier}
  AppLovinSsvVerifier({
    required String signingKey,
    required Logger log,
  }) : _signingKey = signingKey,
       _log = log;

  final String _signingKey;
  final Logger _log;

  @override
  Future<VerifiedRewardPayload> verify(Uri uri) async {
    final callback = AppLovinRewardCallback.fromUri(uri);

    // 1. Construct the string to sign: eventId + userId + ts + KEY
    // Note: The exact concatenation order depends on AppLovin's specific macro setup.
    // Standard MAX S2S usually expects: MD5(event_id + user_id + ts + SECRET_KEY)
    // However, we must ensure this matches the macro configured in the dashboard.
    // We assume the standard format here.
    final inputString =
        '${callback.eventId}${callback.userId}${callback.timestamp}$_signingKey';

    // 2. Calculate MD5 Hash
    final bytes = utf8.encode(inputString);
    final digest = md5.convert(bytes);
    final calculatedSignature = digest.toString();

    // 3. Compare Signatures
    if (calculatedSignature != callback.signature) {
      _log.warning(
        'AppLovin signature mismatch. Calculated: $calculatedSignature, Received: ${callback.signature}',
      );
      throw const InvalidInputException('Invalid signature.');
    }

    final rewardType = RewardType.values.firstWhere(
      (e) => e.name.toLowerCase() == callback.rewardItem.toLowerCase(),
      orElse: () => throw const BadRequestException('Unknown reward type.'),
    );

    _log.info('AppLovin signature verified for event ${callback.eventId}');
    return VerifiedRewardPayload(
      transactionId: callback.eventId,
      userId: callback.userId,
      rewardType: rewardType,
    );
  }
}
