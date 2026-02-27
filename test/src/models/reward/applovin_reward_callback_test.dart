import 'package:core/core.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/reward/applovin_reward_callback.dart';
import 'package:test/test.dart';

void main() {
  group('AppLovinRewardCallback', () {
    test('fromUri parses valid URI correctly', () {
      final uri = Uri.parse(
        'https://api.com/webhook?event_id=evt1&user_id=user1&ts=12345&signature=sig&reward_type=adFree',
      );

      final callback = AppLovinRewardCallback.fromUri(uri);

      expect(callback.eventId, 'evt1');
      expect(callback.userId, 'user1');
      expect(callback.timestamp, '12345');
      expect(callback.signature, 'sig');
      expect(callback.rewardItem, 'adFree');
    });

    test('fromUri accepts custom_data as fallback for reward_type', () {
      final uri = Uri.parse(
        'https://api.com/webhook?event_id=evt1&user_id=user1&ts=12345&signature=sig&custom_data=adFree',
      );

      final callback = AppLovinRewardCallback.fromUri(uri);

      expect(callback.rewardItem, 'adFree');
    });

    test(
      'fromUri throws InvalidInputException when required params are missing',
      () {
        final uris = [
          Uri.parse(
            'https://api.com?user_id=u&ts=1&signature=s&reward_type=r',
          ), // Missing event_id
          Uri.parse(
            'https://api.com?event_id=e&ts=1&signature=s&reward_type=r',
          ), // Missing user_id
          Uri.parse(
            'https://api.com?event_id=e&user_id=u&signature=s&reward_type=r',
          ), // Missing ts
          Uri.parse(
            'https://api.com?event_id=e&user_id=u&ts=1&reward_type=r',
          ), // Missing signature
          Uri.parse(
            'https://api.com?event_id=e&user_id=u&ts=1&signature=s',
          ), // Missing reward_type/custom_data
        ];

        for (final uri in uris) {
          expect(
            () => AppLovinRewardCallback.fromUri(uri),
            throwsA(isA<InvalidInputException>()),
          );
        }
      },
    );

    test('props are correct', () {
      const callback = AppLovinRewardCallback(
        eventId: '1',
        userId: '2',
        timestamp: '3',
        signature: '4',
        rewardItem: '5',
      );
      expect(callback.props, ['1', '2', '3', '4', '5']);
    });
  });
}
