import 'package:ht_api/src/feed_enhancement/feed_decorator.dart';
import 'package:ht_api/src/feed_enhancement/feed_enhancement_context.dart';
import 'package:ht_shared/ht_shared.dart';

/// {@template feed_enhancement_service}
/// Orchestrates the process of enhancing a primary feed with injected content
/// from various [FeedDecorator]s.
/// {@endtemplate}
class FeedEnhancementService {
  /// {@macro feed_enhancement_service}
  const FeedEnhancementService({
    required List<FeedDecorator> decorators,
  }) : _decorators = decorators;

  final List<FeedDecorator> _decorators;

  /// Enhances a list of [primaryItems] by applying a chain of [FeedDecorator]s.
  ///
  /// - [primaryItems]: The initial list of primary feed items (e.g., Headlines).
  /// - [context]: The [FeedEnhancementContext] providing necessary data and repositories.
  ///
  /// Returns a new list of [FeedItem]s that includes both primary and injected content.
  Future<List<FeedItem>> enhanceFeed(
    List<FeedItem> primaryItems,
    FeedEnhancementContext context,
  ) async {
    var currentFeed = List<FeedItem>.from(primaryItems);

    for (final decorator in _decorators) {
      currentFeed = await decorator.decorate(currentFeed, context);
    }

    return currentFeed;
  }
}
