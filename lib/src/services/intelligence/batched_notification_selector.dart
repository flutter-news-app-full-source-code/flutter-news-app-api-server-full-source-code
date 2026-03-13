import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:verity_api/src/services/push_notification/push_notification_service.dart';

/// {@template batched_notification_selector}
/// Selects the best breaking news headlines to notify users about, preventing spam.
///
/// Strategy: "Top-1 per Filter"
/// For each user filter subscribed to breaking news, we find all matching
/// headlines from the current ingestion batch. We then select ONLY the one
/// with the highest `breakingConfidence` score.
/// {@endtemplate}
class BatchedNotificationSelector {
  /// {@macro batched_notification_selector}
  BatchedNotificationSelector({
    required IPushNotificationService pushNotificationService,
    required Logger log,
  }) : _pushService = pushNotificationService,
       _log = log;

  final IPushNotificationService _pushService;
  final Logger _log;

  /// Processes a batch of potential breaking news and dispatches notifications.
  ///
  /// **Spam Prevention Strategy: "Topic Clustering"**
  /// Instead of notifying for every breaking headline (which causes fatigue),
  /// we group concurrent headlines by [Topic].
  ///
  /// Logic:
  /// 1. Filter out candidates with low breaking confidence (< 0.7).
  /// 2. Group the remaining candidates by their `topic.id`.
  /// 3. For each topic group, select ONLY the single headline with the
  ///    highest confidence score.
  ///
  /// This ensures that if 5 articles about "US Politics" break at once,
  /// users receive only the definitive story, while still allowing a concurrent
  /// "Technology" story to be delivered.
  Future<void> processBatch({
    required List<Headline> candidates,
    required Map<String, double> confidenceScores,
  }) async {
    if (candidates.isEmpty) return;

    _log.info('Processing ${candidates.length} breaking news candidates...');

    // 1. Group by Topic ID
    // We use a Map<TopicId, List<Headline>> to create clusters.
    final byTopic = <String, List<Headline>>{};

    for (final headline in candidates) {
      final score = confidenceScores[headline.id] ?? 0.0;

      // Filter out noise
      if (score < 0.7) {
        _log.finer('Dropped low confidence candidate: ${headline.id} ($score)');
        continue;
      }

      byTopic.putIfAbsent(headline.topic.id, () => []).add(headline);
    }

    // 2. Select the Winner for each Topic Cluster
    final selectedHeadlines = <Headline>[];

    for (final topicId in byTopic.keys) {
      final cluster = byTopic[topicId]!;

      // Sort descending by score to find the winner
      cluster.sort((a, b) {
        final scoreA = confidenceScores[a.id] ?? 0.0;
        final scoreB = confidenceScores[b.id] ?? 0.0;
        return scoreB.compareTo(scoreA);
      });

      final winner = cluster.first;
      selectedHeadlines.add(winner);

      _log.info(
        'Topic Clustering: Selected ${winner.id} (Score: ${confidenceScores[winner.id]}) '
        'from a cluster of ${cluster.length} articles for topic "${winner.topic.name.values.first}".',
      );
    }

    _log.info(
      'Dispatching ${selectedHeadlines.length} deduplicated notifications.',
    );

    // 3. Dispatch Notifications
    for (final headline in selectedHeadlines) {
      try {
        await _pushService.sendBreakingNewsNotification(headline: headline);
      } catch (e, s) {
        _log.severe('Failed to dispatch notification for ${headline.id}', e, s);
      }
    }
  }
}
