import 'package:core/core.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/reward/admob_reward_callback.dart';
import 'package:test/test.dart';

void main() {
  group('AdMobRewardCallback', () {
    const validUriString =
        'https://example.com/webhook?transaction_id=trans123&user_id=user123&custom_data=adFree&reward_amount=5&signature=sig123&key_id=key123';

    test('fromUri parses valid URI correctly', () {
      final uri = Uri.parse(validUriString);
      final callback = AdMobRewardCallback.fromUri(uri);

      expect(callback.transactionId, equals('trans123'));
      expect(callback.userId, equals('user123'));
      expect(callback.rewardItem, equals('adFree'));
      expect(callback.rewardAmount, equals(5));
      expect(callback.signature, equals('sig123'));
      expect(callback.keyId, equals('key123'));
      expect(callback.originalUri, equals(uri));
    });

    test('fromUri defaults rewardAmount to 1 if missing', () {
      final uri = Uri.parse(
        'https://example.com/webhook?transaction_id=t&user_id=u&custom_data=adFree&signature=s&key_id=k',
      );
      final callback = AdMobRewardCallback.fromUri(uri);
      expect(callback.rewardAmount, equals(1));
    });

    test('fromUri defaults rewardAmount to 1 if invalid', () {
      final uri = Uri.parse(
        'https://example.com/webhook?transaction_id=t&user_id=u&custom_data=adFree&reward_amount=invalid&signature=s&key_id=k',
      );
      final callback = AdMobRewardCallback.fromUri(uri);
      expect(callback.rewardAmount, equals(1));
    });

    test(
      'fromUri throws InvalidInputException when required fields are missing',
      () {
        final params = {
          'transaction_id': 't',
          'user_id': 'u',
          'custom_data': 'adFree',
          'signature': 's',
          'key_id': 'k',
        };

        // Test missing transaction_id
        var uri = Uri(
          scheme: 'https',
          host: 'e.com',
          queryParameters: Map.from(params)..remove('transaction_id'),
        );
        expect(
          () => AdMobRewardCallback.fromUri(uri),
          throwsA(isA<InvalidInputException>()),
        );

        // Test missing user_id
        uri = Uri(
          scheme: 'https',
          host: 'e.com',
          queryParameters: Map.from(params)..remove('user_id'),
        );
        expect(
          () => AdMobRewardCallback.fromUri(uri),
          throwsA(isA<InvalidInputException>()),
        );

        // Test missing custom_data (which maps to rewardItem)
        uri = Uri(
          scheme: 'https',
          host: 'e.com',
          queryParameters: Map.from(params)..remove('custom_data'),
        );
        expect(
          () => AdMobRewardCallback.fromUri(uri),
          throwsA(isA<InvalidInputException>()),
        );

        // Test missing signature
        uri = Uri(
          scheme: 'https',
          host: 'e.com',
          queryParameters: Map.from(params)..remove('signature'),
        );
        expect(
          () => AdMobRewardCallback.fromUri(uri),
          throwsA(isA<InvalidInputException>()),
        );
      },
    );

    test('props are correct', () {
      final uri = Uri.parse(validUriString);
      final callback = AdMobRewardCallback.fromUri(uri);
      expect(
        callback.props,
        equals([
          'trans123',
          'user123',
          'adFree',
          5,
          'sig123',
          'key123',
          uri,
        ]),
      );
    });
  });
}
