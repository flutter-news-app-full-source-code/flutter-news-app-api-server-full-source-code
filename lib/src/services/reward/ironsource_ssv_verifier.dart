import 'dart:convert';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/reward/ironsource_reward_callback.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/reward/verified_reward_payload.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/reward/reward_verifier.dart';
import 'package:logging/logging.dart';

/// {@template ironsource_ssv_verifier}
/// Verifies Server-Side Verification (SSV) callbacks from IronSource.
///
/// This class implements the HMAC-SHA256 verification logic required by
/// IronSource to ensure that a reward callback is authentic.
/// {@endtemplate}
class IronSourceSsvVerifier implements RewardVerifier {
  /// {@macro ironsource_ssv_verifier}
  const IronSourceSsvVerifier({required this.log});

  final Logger log;

  @override
  Future<VerifiedRewardPayload> verify(Uri uri) async {
    final privateKey = EnvironmentConfig.ironSourceSsvPrivateKey;
    if (privateKey == null) {
      log.severe('IRONSOURCE_SSV_PRIVATE_KEY is not set.');
      throw const ServerException('IronSource verifier is not configured.');
    }

    final callback = IronSourceRewardCallback.fromUri(uri);

    // 1. Construct the content string to verify.
    // IronSource requires a specific concatenation of parameters.
    final contentString =
        '${callback.timestamp}${callback.eventId}${callback.appUserId}${callback.rewards}';

    // 2. Generate the expected signature.
    final keyBytes = utf8.encode(privateKey);
    final contentBytes = utf8.encode(contentString);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(contentBytes);
    final expectedSignature = digest.toString();

    // 3. Compare signatures.
    if (expectedSignature != callback.signature) {
      log.warning(
        'IronSource SSV signature verification failed. '
        'Expected: $expectedSignature, Got: ${callback.signature}',
      );
      throw const InvalidInputException('Invalid signature.');
    }

    log.info('IronSource SSV signature verified successfully.');

    // 4. Parse the 'rewards' string (e.g., "10 adFree")
    final rewardParts = callback.rewards.split(' ');
    if (rewardParts.length != 2) {
      throw InvalidInputException(
        'Invalid rewards format: ${callback.rewards}',
      );
    }
    final rewardItemName = rewardParts[1];

    final rewardType = RewardType.values.firstWhere(
      (e) => e.name.toLowerCase() == rewardItemName.toLowerCase(),
      orElse: () => throw BadRequestException(
        'Unknown reward type: $rewardItemName',
      ),
    );

    return VerifiedRewardPayload(
      // Use eventId as the unique transaction identifier.
      transactionId: callback.eventId,
      userId: callback.appUserId,
      rewardType: rewardType,
    );
  }
}
