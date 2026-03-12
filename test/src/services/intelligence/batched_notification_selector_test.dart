import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:verity_api/src/services/intelligence/batched_notification_selector.dart';
import 'package:verity_api/src/services/push_notification/push_notification_service.dart';

import '../../helpers/test_helpers.dart';

class MockPushNotificationService extends Mock
    implements IPushNotificationService {}

class MockLogger extends Mock implements Logger {}

void main() {
  late BatchedNotificationSelector selector;
  late MockPushNotificationService mockPushService;
  late MockLogger mockLogger;

  setUpAll(registerSharedFallbackValues);

  setUp(() {
    mockPushService = MockPushNotificationService();
    mockLogger = MockLogger();
    selector = BatchedNotificationSelector(
      pushNotificationService: mockPushService,
      log: mockLogger,
    );

    when(
      () => mockPushService.sendBreakingNewsNotification(
        headline: any(named: 'headline'),
      ),
    ).thenAnswer((_) async {});
  });

  group('BatchedNotificationSelector', () {
    test('does nothing if candidates list is empty', () async {
      await selector.processBatch(candidates: [], confidenceScores: {});
      verifyNever(
        () => mockPushService.sendBreakingNewsNotification(
          headline: any(named: 'headline'),
        ),
      );
    });

    test('filters out low confidence headlines', () async {
      final h1 = createTestHeadline(id: 'h1', isBreaking: true);
      await selector.processBatch(
        candidates: [h1],
        confidenceScores: {'h1': 0.6}, // Below 0.7 threshold
      );
      verifyNever(
        () => mockPushService.sendBreakingNewsNotification(
          headline: any(named: 'headline'),
        ),
      );
    });

    test('selects single highest scoring headline per topic', () async {
      final topicA = createTestHeadline().topic.copyWith(id: 'topic-a');

      final h1 = createTestHeadline(id: 'h1', topic: topicA);
      final h2 = createTestHeadline(id: 'h2', topic: topicA);
      final h3 = createTestHeadline(id: 'h3', topic: topicA);

      await selector.processBatch(
        candidates: [h1, h2, h3],
        confidenceScores: {
          'h1': 0.8,
          'h2': 0.95, // Winner
          'h3': 0.75,
        },
      );

      verify(
        () => mockPushService.sendBreakingNewsNotification(headline: h2),
      ).called(1);
      verifyNever(
        () => mockPushService.sendBreakingNewsNotification(headline: h1),
      );
      verifyNever(
        () => mockPushService.sendBreakingNewsNotification(headline: h3),
      );
    });

    test('sends multiple notifications for different topics', () async {
      final topicA = createTestHeadline().topic.copyWith(id: 'topic-a');
      final topicB = createTestHeadline().topic.copyWith(id: 'topic-b');

      final h1 = createTestHeadline(id: 'h1', topic: topicA);
      final h2 = createTestHeadline(id: 'h2', topic: topicB);

      await selector.processBatch(
        candidates: [h1, h2],
        confidenceScores: {
          'h1': 0.9,
          'h2': 0.9,
        },
      );

      verify(
        () => mockPushService.sendBreakingNewsNotification(headline: h1),
      ).called(1);
      verify(
        () => mockPushService.sendBreakingNewsNotification(headline: h2),
      ).called(1);
    });

    test('handles exceptions from push service gracefully', () async {
      final h1 = createTestHeadline(id: 'h1');

      when(
        () => mockPushService.sendBreakingNewsNotification(headline: h1),
      ).thenThrow(Exception('Push failed'));

      // Should not throw
      await selector.processBatch(
        candidates: [h1],
        confidenceScores: {'h1': 0.9},
      );

      verify(
        () => mockPushService.sendBreakingNewsNotification(headline: h1),
      ).called(1);
      verify(() => mockLogger.severe(any(), any(), any())).called(1);
    });
  });
}
