import 'package:ht_api/src/feed_enhancement/feed_decorator.dart';
import 'package:ht_api/src/feed_enhancement/feed_enhancement_context.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:uuid/uuid.dart';

/// {@template suggested_content_decorator}
/// A [FeedDecorator] that injects [SuggestedContent] items into the feed
/// based on [AppConfig.suggestionRules] and the user's preferences.
/// {@endtemplate}
class SuggestedContentDecorator implements FeedDecorator {
  /// {@macro suggested_content_decorator}
  const SuggestedContentDecorator({Uuid? uuidGenerator})
      : _uuid = uuidGenerator ?? const Uuid();

  final Uuid _uuid;

  @override
  Future<List<FeedItem>> decorate(
    List<FeedItem> currentFeedItems,
    FeedEnhancementContext context,
  ) async {
    final user = context.authenticatedUser;
    final appConfig = context.appConfig;
    final suggestedTemplateRepository =
        context.suggestedContentTemplateRepository;
    final categoryRepository = context.categoryRepository;
    final sourceRepository = context.sourceRepository;
    final countryRepository = context.countryRepository;

    final rules = appConfig.suggestionRules;
    if (rules.isEmpty) {
      return currentFeedItems;
    }

    final decoratedFeed = <FeedItem>[...currentFeedItems];

    // Find a suitable suggestion to inject
    SuggestionRule? ruleToInject;
    SuggestedContentTemplate? templateToInject;
    var dynamicItems = <FeedItem>[];

    for (final rule in rules) {
      // 1. Check user role
      if (!rule.userRoles.contains(user.role)) {
        continue;
      }

      // 2. Fetch the template content
      try {
        templateToInject = await suggestedTemplateRepository.read(
          id: rule.templateType.name,
        );
      } on NotFoundException {
        print(
          'Warning: Suggested content template "${rule.templateType.name}" not found.',
        );
        continue; // Skip this rule if template is missing
      } catch (e) {
        print(
          'Error fetching suggested content template "${rule.templateType.name}": $e',
        );
        continue;
      }

      // 3. Fetch dynamic items based on template's suggestedContentType and fetchCriteria
      try {
        switch (templateToInject.suggestedContentType) {
          case ContentType.category:
            // Example: Fetch popular categories
            final categories = await categoryRepository.readAllByQuery(
              {'sortBy': templateToInject.fetchCriteria ?? 'popular'},
              limit: templateToInject.maxItemsToDisplay,
            );
            dynamicItems = categories.items.cast<FeedItem>();
          case ContentType.source:
            // Example: Fetch recommended sources
            final sources = await sourceRepository.readAllByQuery(
              {'sortBy': templateToInject.fetchCriteria ?? 'recommended'},
              limit: templateToInject.maxItemsToDisplay,
            );
            dynamicItems = sources.items.cast<FeedItem>();
          case ContentType.country:
            // Example: Fetch popular countries
            final countries = await countryRepository.readAllByQuery(
              {'sortBy': templateToInject.fetchCriteria ?? 'popular'},
              limit: templateToInject.maxItemsToDisplay,
            );
            dynamicItems = countries.items.cast<FeedItem>();
          default:
            print(
              'Warning: Unsupported suggestedContentType '
              '${templateToInject.suggestedContentType.name} for template '
              '"${templateToInject.type.name}".',
            );
            continue;
        }
      } on HtHttpException catch (e) {
        print(
          'Error fetching dynamic items for suggested content '
          '"${templateToInject.type.name}": $e',
        );
        continue;
      } catch (e) {
        print(
          'Unexpected error fetching dynamic items for suggested content '
          '"${templateToInject.type.name}": $e',
        );
        continue;
      }

      // Only inject if we actually got some dynamic items
      if (dynamicItems.isNotEmpty) {
        ruleToInject = rule;
        break; // Found a suitable rule and fetched items, break loop
      }
    }

    if (ruleToInject != null && templateToInject != null) {
      final suggestedItem = SuggestedContent(
        id: _uuid.v4(),
        title: templateToInject.title,
        description: templateToInject.description,
        displayType: templateToInject.displayType,
        items: dynamicItems,
        action: const OpenInternalContent(
          contentId: 'suggested_content_view', // Placeholder for client action
          contentType: ContentType.category, // Example, could be dynamic
        ),
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
          decoratedFeed.insert(
            placement.afterPrimaryItemIndex! + 1,
            suggestedItem,
          );
          inserted = true;
        } else if (placement.relativePosition == 'middle' &&
            decoratedFeed.isNotEmpty) {
          final middleIndex = (decoratedFeed.length / 2).floor();
          decoratedFeed.insert(middleIndex, suggestedItem);
          inserted = true;
        }
      }

      // If no specific placement or placement failed, append to end (fallback)
      if (!inserted) {
        decoratedFeed.add(suggestedItem);
      }
    }

    return decoratedFeed;
  }
}
