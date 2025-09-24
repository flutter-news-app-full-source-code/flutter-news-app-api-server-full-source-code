import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/database/migration.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template refactor_ad_config_to_role_based}
/// A comprehensive migration to refactor the `adConfig` structure within
/// `RemoteConfig` documents to a new role-based `visibleTo` map approach.
///
/// This migration addresses significant changes introduced by a PR (see
/// [gitHubPullRequest]) that aimed to enhance flexibility and maintainability
/// of ad configurations. It transforms old, role-specific ad frequency and
/// placement fields into new `visibleTo` maps for `FeedAdConfiguration`,
/// `ArticleAdConfiguration`, and `InterstitialAdConfiguration`.
///
/// The migration ensures that existing `RemoteConfig` documents are updated
/// to conform to the latest model structure, preventing deserialization errors
/// and enabling granular control over ad display for different user roles.
/// {@endtemplate}
class RefactorAdConfigToRoleBased extends Migration {
  /// {@macro refactor_ad_config_to_role_based}
  RefactorAdConfigToRoleBased()
    : super(
        prDate: '20250924084800',
        prSummary: 'Refactor adConfig to use role-based visibleTo maps',
        prId: '50',
      );

  @override
  Future<void> up(Db db, Logger log) async {
    log.info(
      'Applying migration PR#$prId (Date: $prDate): $prSummary.',
    );

    final remoteConfigCollection = db.collection('remote_configs');

    // Define default FeedAdFrequencyConfig for roles
    const defaultGuestFeedAdFrequency = FeedAdFrequencyConfig(
      adFrequency: 5,
      adPlacementInterval: 3,
    );
    const defaultStandardUserFeedAdFrequency = FeedAdFrequencyConfig(
      adFrequency: 10,
      adPlacementInterval: 5,
    );
    // Define default InterstitialAdFrequencyConfig for roles
    const defaultGuestInterstitialAdFrequency = InterstitialAdFrequencyConfig(
      transitionsBeforeShowingInterstitialAds: 5,
    );
    const defaultStandardUserInterstitialAdFrequency =
        InterstitialAdFrequencyConfig(
          transitionsBeforeShowingInterstitialAds: 10,
        );

    // Define default ArticleAdSlot visibility for roles
    final defaultArticleAdSlots = {
      InArticleAdSlotType.aboveArticleContinueReadingButton.name: true,
      InArticleAdSlotType.belowArticleContinueReadingButton.name: true,
    };

    final result = await remoteConfigCollection.updateMany(
      // Find documents that still have the old structure (e.g., old frequency fields)
      where.exists(
        'adConfig.feedAdConfiguration.frequencyConfig.guestAdFrequency',
      ),
      ModifierBuilder()
        // --- FeedAdConfiguration Transformation ---
        // Remove old frequencyConfig fields
        ..unset('adConfig.feedAdConfiguration.frequencyConfig.guestAdFrequency')
        ..unset(
          'adConfig.feedAdConfiguration.frequencyConfig.guestAdPlacementInterval',
        )
        ..unset(
          'adConfig.feedAdConfiguration.frequencyConfig.authenticatedAdFrequency',
        )
        ..unset(
          'adConfig.feedAdConfiguration.frequencyConfig.authenticatedAdPlacementInterval',
        )
        ..unset(
          'adConfig.feedAdConfiguration.frequencyConfig.premiumAdFrequency',
        )
        ..unset(
          'adConfig.feedAdConfiguration.frequencyConfig.premiumAdPlacementInterval',
        )
        // Set the new visibleTo map for FeedAdConfiguration
        ..set(
          'adConfig.feedAdConfiguration.visibleTo',
          {
            AppUserRole.guestUser.name: defaultGuestFeedAdFrequency.toJson(),
            AppUserRole.standardUser.name: defaultStandardUserFeedAdFrequency
                .toJson(),
          },
        )
        // --- ArticleAdConfiguration Transformation ---
        // Remove old inArticleAdSlotConfigurations list
        ..unset('adConfig.articleAdConfiguration.inArticleAdSlotConfigurations')
        // Set the new visibleTo map for ArticleAdConfiguration
        ..set(
          'adConfig.articleAdConfiguration.visibleTo',
          {
            AppUserRole.guestUser.name: defaultArticleAdSlots,
            AppUserRole.standardUser.name: defaultArticleAdSlots,
          },
        )
        // --- InterstitialAdConfiguration Transformation ---
        // Remove old feedInterstitialAdFrequencyConfig fields
        ..unset(
          'adConfig.interstitialAdConfiguration.feedInterstitialAdFrequencyConfig.guestTransitionsBeforeShowingInterstitialAds',
        )
        ..unset(
          'adConfig.interstitialAdConfiguration.feedInterstitialAdFrequencyConfig.standardUserTransitionsBeforeShowingInterstitialAds',
        )
        ..unset(
          'adConfig.interstitialAdConfiguration.feedInterstitialAdFrequencyConfig.premiumUserTransitionsBeforeShowingInterstitialAds',
        )
        // Set the new visibleTo map for InterstitialAdConfiguration
        ..set(
          'adConfig.interstitialAdConfiguration.visibleTo',
          {
            AppUserRole.guestUser.name: defaultGuestInterstitialAdFrequency
                .toJson(),
            AppUserRole.standardUser.name:
                defaultStandardUserInterstitialAdFrequency.toJson(),
          },
        ),
    );

    log.info(
      'Updated ${result.nModified} remote_config documents '
      'to new role-based adConfig structure.',
    );
  }

  @override
  Future<void> down(Db db, Logger log) async {
    log.warning(
      'Reverting migration: Revert adConfig to old structure '
      '(not recommended for production).',
    );
    // This down migration is complex and primarily for development/testing rollback.
    // Reverting to the old structure would require re-introducing the old fields
    // and potentially losing data if the new structure was used.
    // For simplicity in this example, we'll just unset the new fields.
    final result = await db
        .collection('remote_configs')
        .updateMany(
          where.exists('adConfig.feedAdConfiguration.visibleTo'),
          ModifierBuilder()
            ..unset('adConfig.feedAdConfiguration.visibleTo')
            ..unset('adConfig.articleAdConfiguration.visibleTo')
            ..unset('adConfig.interstitialAdConfiguration.visibleTo'),
        );
    log.warning(
      'Reverted ${result.nModified} remote_config documents '
      'by unsetting new adConfig fields.',
    );
  }
}
