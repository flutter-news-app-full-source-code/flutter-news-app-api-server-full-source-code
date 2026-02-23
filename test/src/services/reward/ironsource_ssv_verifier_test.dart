import 'dart:convert';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/reward/ironsource_ssv_verifier.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  group('IronSourceSsvVerifier', () {
    late IronSourceSsvVerifier verifier;
    late MockLogger mockLogger;

    const privateKey = 'test-private-key';
    const timestamp = '1672531200';
    const eventId = 'test-event-id';
    const appUserId = 'test-user-id';
    const rewards = '10 adFree';

    late Uri validUri;

    setUp(() {
      mockLogger = MockLogger();
      verifier = IronSourceSsvVerifier(log: mockLogger);

      // Set the private key for tests.
      EnvironmentConfig.setOverride('IRONSOURCE_SSV_PRIVATE_KEY', privateKey);

      // Calculate signature at runtime to avoid brittleness.
      const contentStringForSig = '$timestamp$eventId$appUserId$rewards';
      final hmacForSig = Hmac(sha256, utf8.encode(privateKey));
      final digestForSig = hmacForSig.convert(utf8.encode(contentStringForSig));
      final validSignature = digestForSig.toString();

      validUri = Uri.parse(
        'https://example.com/callback?timestamp=$timestamp&eventId=$eventId&appUserId=$appUserId&rewards=$rewards&signature=$validSignature',
      );
    });

    tearDown(() {
      // Clear the override after each test.
      EnvironmentConfig.setOverride('IRONSOURCE_SSV_PRIVATE_KEY', null);
    });

    test('verify returns VerifiedRewardPayload on valid signature', () async {
      final result = await verifier.verify(validUri);

      expect(result.transactionId, eventId);
      expect(result.userId, appUserId);
      expect(result.rewardType, RewardType.adFree);
    });

    test('verify throws InvalidInputException on invalid signature', () async {
      final invalidUri = validUri.replace(
        queryParameters: {
          ...validUri.queryParameters,
          'signature': 'invalid-signature',
        },
      );

      expect(
        () => verifier.verify(invalidUri),
        throwsA(isA<InvalidInputException>()),
      );
    });

    test('verify throws ServerException if private key is not set', () async {
      // Unset the private key for this specific test.
      EnvironmentConfig.setOverride('IRONSOURCE_SSV_PRIVATE_KEY', null);

      expect(
        () => verifier.verify(validUri),
        throwsA(isA<ServerException>()),
      );
    });

    test(
      'verify throws InvalidInputException for missing parameters',
      () async {
        final incompleteUri = Uri.parse(
          'https://example.com/callback?timestamp=$timestamp&eventId=$eventId',
        );

        expect(
          () => verifier.verify(incompleteUri),
          throwsA(isA<InvalidInputException>()),
        );
      },
    );

    test(
      'verify throws InvalidInputException for invalid rewards format',
      () async {
        final malformedRewardsUri = validUri.replace(
          queryParameters: {
            ...validUri.queryParameters,
            'rewards': 'invalidFormat',
          },
        );

        // Re-sign with the malformed rewards string to pass signature check.
        final contentString =
            '$timestamp$eventId$appUserId${malformedRewardsUri.queryParameters['rewards']}';
        final hmac = Hmac(sha256, utf8.encode(privateKey));
        final digest = hmac.convert(utf8.encode(contentString));
        final newSignature = digest.toString();

        final signedMalformedUri = malformedRewardsUri.replace(
          queryParameters: {
            ...malformedRewardsUri.queryParameters,
            'signature': newSignature,
          },
        );

        expect(
          () => verifier.verify(signedMalformedUri),
          throwsA(isA<InvalidInputException>()),
        );
      },
    );

    test('verify throws BadRequestException for unknown reward type', () async {
      final unknownRewardUri = validUri.replace(
        queryParameters: {
          ...validUri.queryParameters,
          'rewards': '10 unknownReward',
        },
      );

      // Re-sign to pass signature check.
      final contentString =
          '$timestamp$eventId$appUserId${unknownRewardUri.queryParameters['rewards']}';
      final hmac = Hmac(sha256, utf8.encode(privateKey));
      final digest = hmac.convert(utf8.encode(contentString));
      final newSignature = digest.toString();

      final signedUnknownUri = unknownRewardUri.replace(
        queryParameters: {
          ...unknownRewardUri.queryParameters,
          'signature': newSignature,
        },
      );

      expect(
        () => verifier.verify(signedUnknownUri),
        throwsA(isA<BadRequestException>()),
      );
    });
  });
}
