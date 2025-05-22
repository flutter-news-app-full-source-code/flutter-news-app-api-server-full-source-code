import 'package:ht_api/src/feed_enhancement/feed_decorator.dart';
import 'package:ht_api/src/feed_enhancement/feed_enhancement_context.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:uuid/uuid.dart';

/// {@template engagement_decorator}
/// A [FeedDecorator] that injects [EngagementContent] items into the feed
/// based on [AppConfig.engagementRules] and the user's state.
/// {@endtemplate}
class EngagementDecorator implements FeedDecorator {
  /// {@macro engagement_decorator}
  const EngagementDecorator({Uuid? uuidGenerator})
      : _uuid = uuidGenerator ?? const Uuid();

  final Uuid _uuid;

  @override
  Future<List<FeedItem>> decorate(
    List<FeedItem> currentFeedItems,
    FeedEnhancementContext context,
  ) async {
    final user = context.authenticatedUser;
    final appConfig = context.appConfig;
    final userAppSettingsRepository = context.userAppSettingsRepository;
    final engagementTemplateRepository =
        context.engagementContentTemplateRepository;

    final rules = appConfig.engagementRules;
    if (rules.isEmpty) {
      return currentFeedItems;
    }

    final decoratedFeed = <FeedItem>[...currentFeedItems];
    final now = DateTime.now().toUtc();

    // Fetch user app settings to check engagement history
    UserAppSettings userAppSettings;
    try {
      userAppSettings = await userAppSettingsRepository.read(id: user.id);
    } on NotFoundException {
      // If settings not found, create default ones (should be handled by auth)
      // or assume no history for this session. For now, use default.
      userAppSettings = UserAppSettings(id: user.id);
    } catch (e) {
      print('Error fetching UserAppSettings for engagement: $e');
      // Fail gracefully, don't inject engagements if settings can't be read
      return currentFeedItems;
    }

    // Keep track of changes to userAppSettings to save them later
    var updatedAppSettings = userAppSettings;
    var appSettingsUpdated = false;

    // Variables to hold the selected rule and template
    EngagementRule? ruleToInject;
    EngagementContentTemplate? templateToInject;
    int selectedRuleShownCount = 0; // Initialize to 0

    for (final rule in rules) {
      // 1. Check user role
      if (!rule.userRoles.contains(user.role)) {
        continue;
      }

      // 2. Check minDaysSinceAccountCreation
      if (rule.minDaysSinceAccountCreation != null && user.createdAt != null) {
        final daysSinceCreation = now.difference(user.createdAt!).inDays;
        if (daysSinceCreation < rule.minDaysSinceAccountCreation!) {
          continue;
        }
      }

      // 3. Check maxTimesToShow
      final currentShownCount =
          updatedAppSettings.engagementShownCounts[rule.templateType.name] ?? 0;
      if (rule.maxTimesToShow != null &&
          currentShownCount >= rule.maxTimesToShow!) {
        continue;
      }

      // 4. Check minDaysSinceLastShown
      final lastShownTimestamp =
          updatedAppSettings.engagementLastShownTimestamps[rule.templateType.name];
      if (rule.minDaysSinceLastShown != null && lastShownTimestamp != null) {
        final daysSinceLastShown = now.difference(lastShownTimestamp).inDays;
        if (daysSinceLastShown < rule.minDaysSinceLastShown!) {
          continue;
        }
      }

      // 5. Fetch the template content
      try {
        templateToInject = await engagementTemplateRepository.read(
          id: rule.templateType.name,
        );
      } on NotFoundException {
        print(
          'Warning: Engagement template "${rule.templateType.name}" not found.',
        );
        continue; // Skip this rule if template is missing
      } catch (e) {
        print(
          'Error fetching engagement template "${rule.templateType.name}": $e',
        );
        continue;
      }

      // If we reach here, this rule is a candidate.
      // For simplicity, we'll inject the first valid one found.
      ruleToInject = rule;
      selectedRuleShownCount = currentShownCount; // Capture for the selected rule
      break; // Exit loop after finding the first suitable rule
    }

    if (ruleToInject != null && templateToInject != null) {
      final engagementItem = EngagementContent(
        id: _uuid.v4(),
        title: templateToInject.title,
        description: templateToInject.description,
        callToActionText: templateToInject.callToActionText,
        engagementContentType:
            EngagementContentType.values.byName(ruleToInject.templateType.name),
        // Action for the client to perform when this is tapped.
        // This could be more dynamic based on templateType or rule.
        action: const OpenExternalUrl(url: 'https://example.com/engagement_action'),
      );

      // Determine placement (simple for now, can be enhanced)
      final placement = ruleToInject.placement;
      var inserted = false;

      if (placement != null) {
        if (placement.minPrimaryItemsRequired != null &&
            currentFeedItems.length < placement.minPrimaryItemsRequired!) {
          // Not enough primary items for this placement, do not insert
        } else if (placement.afterPrimaryItemIndex != null &&
            placement.afterPrimaryItemIndex! < decoratedFeed.length) {
          decoratedFeed.insert(placement.afterPrimaryItemIndex! + 1, engagementItem);
          inserted = true;
        } else if (placement.relativePosition == 'middle' &&
            decoratedFeed.isNotEmpty) {
          final middleIndex = (decoratedFeed.length / 2).floor();
          decoratedFeed.insert(middleIndex, engagementItem);
          inserted = true;
        }
      }

      // If no specific placement or placement failed, append to end (fallback)
      if (!inserted) {
        decoratedFeed.add(engagementItem);
      }

      // Update userAppSettings for tracking
      updatedAppSettings = updatedAppSettings.copyWith(
        engagementShownCounts: {
          ...updatedAppSettings.engagementShownCounts,
          ruleToInject.templateType.name: selectedRuleShownCount + 1,
        },
        engagementLastShownTimestamps: {
          ...updatedAppSettings.engagementLastShownTimestamps,
          ruleToInject.templateType.name: now,
        },
      );
      appSettingsUpdated = true;
    }

    // Save updated userAppSettings if changes were made
    if (appSettingsUpdated) {
      try {
        await userAppSettingsRepository.update(
          id: updatedAppSettings.id,
          item: updatedAppSettings,
          userId: user.id,
        );
      } catch (e) {
        print('Error saving updated UserAppSettings for engagement: $e');
        // Log error, but don't prevent feed from being returned
      }
    }

    return decoratedFeed;
  }
}
