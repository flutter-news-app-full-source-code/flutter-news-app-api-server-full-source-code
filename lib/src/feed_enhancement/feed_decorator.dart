import 'package:ht_api/src/feed_enhancement/feed_enhancement_context.dart';
import 'package:ht_shared/ht_shared.dart';

/// {@template feed_decorator}
/// An abstract class defining the interface for components that can
/// intelligently inject [FeedItem]s into a list of primary feed content.
/// {@endtemplate}
abstract class FeedDecorator {
  /// {@macro feed_decorator}
  const FeedDecorator();

  /// Decorates the [currentFeedItems] by potentially injecting new [FeedItem]s.
  ///
  /// - [currentFeedItems]: The list of feed items (primary content, possibly
  ///   already decorated by previous decorators) to be enhanced.
  /// - [context]: Provides necessary information like the authenticated user,
  ///   application configuration, and repositories needed for decision-making
  ///   and fetching dynamic content.
  ///
  /// Returns a new list of [FeedItem]s with injected content.
  Future<List<FeedItem>> decorate(
    List<FeedItem> currentFeedItems,
    FeedEnhancementContext context,
  );
}
