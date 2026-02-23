import 'dart:convert';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/reward/verified_reward_payload.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/reward/applovin_ssv_verifier.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  group('AppLovinSsvVerifier', () {
    late AppLovinSsvVerifier verifier;
    const signingKey = 'my-secret-key';

    setUp(() {
      verifier = AppLovinSsvVerifier(
        signingKey: signingKey,
        log: Logger('TestAppLovinVerifier'),
      );
    });

    String generateSignature(String eventId, String userId, String ts) {
      // MD5(event_id + user_id + ts + SECRET_KEY)
      final input = '$eventId$userId$ts$signingKey';
      return md5.convert(utf8.encode(input)).toString();
    }

    test('verify succeeds with valid signature', () async {
      const eventId = 'evt123';
      const userId = 'user456';
      const ts = '1616161616';
      final signature = generateSignature(eventId, userId, ts);

      final uri = Uri.parse(
        'https://api.com/webhook?event_id=$eventId&user_id=$userId&ts=$ts&signature=$signature&reward_type=adFree',
      );

      final result = await verifier.verify(uri);

      expect(result, isA<VerifiedRewardPayload>());
      expect(result.transactionId, eventId);
      expect(result.userId, userId);
      expect(result.rewardType, RewardType.adFree);
    });

    test('verify throws InvalidInputException for invalid signature', () async {
      final uri = Uri.parse(
        'https://api.com/webhook?event_id=e&user_id=u&ts=1&signature=invalid_sig&reward_type=adFree',
      );

      expect(
        () => verifier.verify(uri),
        throwsA(isA<InvalidInputException>()),
      );
    });

    test('verify throws BadRequestException for unknown reward type', () async {
      final signature = generateSignature('e', 'u', '1');
      final uri = Uri.parse(
        'https://api.com/webhook?event_id=e&user_id=u&ts=1&signature=$signature&reward_type=UNKNOWN',
      );

      expect(() => verifier.verify(uri), throwsA(isA<BadRequestException>()));
    });
  });
}
