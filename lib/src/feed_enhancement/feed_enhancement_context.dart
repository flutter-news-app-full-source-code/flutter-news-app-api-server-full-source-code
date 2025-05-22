import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_shared/ht_shared.dart';

/// {@template feed_enhancement_context}
/// Provides contextual information and necessary dependencies to [FeedDecorator]s
/// during the feed enhancement process.
/// {@endtemplate}
class FeedEnhancementContext {
  /// {@macro feed_enhancement_context}
  const FeedEnhancementContext({
    required this.authenticatedUser,
    required this.appConfig,
    required this.primaryModelName,
    required this.userAppSettingsRepository,
    required this.engagementContentTemplateRepository,
    required this.suggestedContentTemplateRepository,
    required this.categoryRepository,
    required this.sourceRepository,
    required this.countryRepository,
  });

  /// The currently authenticated user.
  final User authenticatedUser;

  /// The application's remote configuration.
  final AppConfig appConfig;

  /// The name of the primary model type being fetched (e.g., 'headline', 'source').
  final String primaryModelName;

  /// Repository for managing user application settings.
  final HtDataRepository<UserAppSettings> userAppSettingsRepository;

  /// Repository for fetching engagement content templates.
  final HtDataRepository<EngagementContentTemplate>
      engagementContentTemplateRepository;

  /// Repository for fetching suggested content templates.
  final HtDataRepository<SuggestedContentTemplate>
      suggestedContentTemplateRepository;

  /// Repository for fetching Category data (used by SuggestedContentDecorator).
  final HtDataRepository<Category> categoryRepository;

  /// Repository for fetching Source data (used by SuggestedContentDecorator).
  final HtDataRepository<Source> sourceRepository;

  /// Repository for fetching Country data (used by SuggestedContentDecorator).
  final HtDataRepository<Country> countryRepository;
}
