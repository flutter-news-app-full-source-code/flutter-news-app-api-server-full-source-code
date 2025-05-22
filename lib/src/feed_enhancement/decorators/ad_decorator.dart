import 'package:ht_api/src/feed_enhancement/feed_decorator.dart';
import 'package:ht_api/src/feed_enhancement/feed_enhancement_context.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:uuid/uuid.dart';

/// {@template ad_decorator}
/// A [FeedDecorator] that injects [Ad] items into the feed based on
/// [AppConfig.adConfig] and the user's role.
///
/// This decorator constructs [Ad] objects as indicators for the client
/// application to render actual ads via its SDK.
/// {@endtemplate}
class AdDecorator implements FeedDecorator {
  /// {@macro ad_decorator}
  const AdDecorator({Uuid? uuidGenerator}) : _uuid = uuidGenerator ?? const Uuid();

  final Uuid _uuid;

  @override
  Future<List<FeedItem>> decorate(
    List<FeedItem> currentFeedItems,
    FeedEnhancementContext context,
  ) async {
    final userRole = context.authenticatedUser.role;
    final adConfig = context.appConfig.adConfig;

    int adFrequency;
    int adPlacementInterval;

    switch (userRole) {
      case UserRole.guestUser:
        adFrequency = adConfig.guestAdFrequency;
        adPlacementInterval = adConfig.guestAdPlacementInterval;
      case UserRole.standardUser:
        adFrequency = adConfig.authenticatedAdFrequency;
        adPlacementInterval = adConfig.authenticatedAdPlacementInterval;
      case UserRole.premiumUser:
        // Premium users typically see no ads
        adFrequency = adConfig.premiumAdFrequency;
        adPlacementInterval = adConfig.premiumAdPlacementInterval;
      case UserRole.admin:
        // Admins typically see no ads in the regular feed
        return currentFeedItems;
    }

    // If adFrequency is 0, no ads for this user role.
    if (adFrequency <= 0) {
      return currentFeedItems;
    }

    final decoratedFeed = <FeedItem>[];
    int primaryItemCount = 0;
    int adsInjected = 0;

    for (var i = 0; i < currentFeedItems.length; i++) {
      decoratedFeed.add(currentFeedItems[i]);
      primaryItemCount++;

      // Check if it's time to inject an ad
      if (primaryItemCount % adFrequency == 0 &&
          primaryItemCount >= adPlacementInterval) {
        // Construct a placeholder Ad item. The client app will interpret this.
        final adItem = Ad(
          id: _uuid.v4(),
          imageUrl: 'https://example.com/placeholder_ad.png',
          targetUrl: 'https://example.com/ad_click_target',
          adType: AdType.banner, // Example ad type
          placement: AdPlacement.feedInlineStandardBanner, // Example placement
          action: const OpenExternalUrl(url: 'https://example.com/ad_click_target'),
        );
        decoratedFeed.add(adItem);
        adsInjected++;
        // Reset primaryItemCount to ensure interval is respected after injection
        primaryItemCount = 0;
      }
    }

    return decoratedFeed;
  }
}
