import 'dart:async';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/rbac/permissions.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/country_query_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/push_notification/push_notification_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/storage/i_storage_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/user_action_limit_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/util/media_asset_utils.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/utils/localization_utils.dart';
import 'package:logging/logging.dart';

// --- Typedefs for Data Operations ---

/// A function that fetches a single item by its ID.
typedef ItemFetcher =
    Future<dynamic> Function(
      RequestContext context,
      String id,
    );

/// A function that fetches a paginated list of items.
typedef AllItemsReader =
    Future<PaginatedResponse<dynamic>> Function(
      RequestContext context,
      String? userId,
      Map<String, dynamic>? filter,
      List<SortOption>? sort,
      PaginationOptions? pagination,
    );

/// A function that creates a new item.
typedef ItemCreator =
    Future<dynamic> Function(
      RequestContext context,
      dynamic item,
      String? userId,
    );

/// A function that updates an existing item.
typedef ItemUpdater =
    Future<dynamic> Function(
      RequestContext context,
      String id,
      dynamic item,
      String? userId,
    );

/// A function that deletes an item by its ID.
typedef ItemDeleter =
    Future<void> Function(
      RequestContext context,
      String id,
      String? userId,
    );

final _log = Logger('DataOperationRegistry');

/// {@template data_operation_registry}
/// A centralized registry for all data handling functions (CRUD operations).
///
/// This class uses a map-based strategy to associate model names (strings)
/// with their corresponding data operation functions. This approach avoids
/// large, repetitive `switch` statements in the route handlers, making the
/// code more maintainable, scalable, and easier to read.
///
/// By centralizing these mappings, we create a single source of truth for how
/// data operations are performed for each model, improving consistency across
/// the API.
///
/// ### Heuristic Branching Strategy (Localization)
/// This registry implements a "Context-Aware Projection" heuristic to serve
/// two distinct client types from a single API:
///
/// 1. **Mobile Clients (Standard Users):**
///    - **Behavior:** Always receive localized data (projected to a single string).
///    - **Reason:** Optimizes payload size and simplifies client-side rendering.
///
/// 2. **CMS/Dashboard (Privileged Users):**
///    - **Behavior:** Receive RAW data (full translation maps) for single-item fetches.
///    - **Reason:** Enables editing of all languages simultaneously.
///    - **Exception:** Collection fetches (Read All) remain localized to keep
///      dashboard tables readable and performant.
/// {@endtemplate}
class DataOperationRegistry {
  /// {@macro data_operation_registry}
  DataOperationRegistry() {
    _log.info(
      'Initializing DataOperationRegistry.',
    );
    _registerOperations();
  }

  // --- Private Maps to Hold Operation Functions ---

  final Map<String, ItemFetcher> _itemFetchers = {};
  final Map<String, AllItemsReader> _allItemsReaders = {};
  final Map<String, ItemCreator> _itemCreators = {};
  final Map<String, ItemUpdater> _itemUpdaters = {};
  final Map<String, ItemDeleter> _itemDeleters = {};

  // --- Public Getters to Access Operation Maps ---

  /// Provides access to the map of item fetcher functions.
  Map<String, ItemFetcher> get itemFetchers => _itemFetchers;

  /// Provides access to the map of collection reader functions.
  Map<String, AllItemsReader> get allItemsReaders => _allItemsReaders;

  /// Provides access to the map of item creator functions.
  Map<String, ItemCreator> get itemCreators => _itemCreators;

  /// Provides access to the map of item updater functions.
  Map<String, ItemUpdater> get itemUpdaters => _itemUpdaters;

  /// Provides access to the map of item deleter functions.
  Map<String, ItemDeleter> get itemDeleters => _itemDeleters;

  /// Populates the operation maps with their respective functions.
  void _registerOperations() {
    // --- Register Item Fetchers ---
    _itemFetchers.addAll({
      'headline': (c, id) async {
        final item = await c.read<DataRepository<Headline>>().read(
          id: id,
          userId: null,
        );
        // CMS users need raw data for editing; Mobile users get localized data.
        if (_isPrivileged(c)) return item;
        final lang = c.read<SupportedLanguage>();
        return LocalizationUtils.localizeHeadline(item, lang);
      },
      'topic': (c, id) async {
        final item = await c.read<DataRepository<Topic>>().read(
          id: id,
          userId: null,
        );
        if (_isPrivileged(c)) return item;
        final lang = c.read<SupportedLanguage>();
        return LocalizationUtils.localizeTopic(item, lang);
      },
      'source': (c, id) async {
        final item = await c.read<DataRepository<Source>>().read(
          id: id,
          userId: null,
        );
        if (_isPrivileged(c)) return item;
        final lang = c.read<SupportedLanguage>();
        return LocalizationUtils.localizeSource(item, lang);
      },
      'country': (c, id) async {
        final item = await c.read<DataRepository<Country>>().read(
          id: id,
          userId: null,
        );
        if (_isPrivileged(c)) return item;
        final lang = c.read<SupportedLanguage>();
        return LocalizationUtils.localizeCountry(item, lang);
      },
      'language': (c, id) async {
        final item = await c.read<DataRepository<Language>>().read(
          id: id,
          userId: null,
        );
        if (_isPrivileged(c)) return item;
        final lang = c.read<SupportedLanguage>();
        return LocalizationUtils.localizeLanguage(item, lang);
      },
      'user': (c, id) =>
          c.read<DataRepository<User>>().read(id: id, userId: null),
      'app_settings': (c, id) =>
          c.read<DataRepository<AppSettings>>().read(id: id, userId: null),
      'user_context': (c, id) =>
          c.read<DataRepository<UserContext>>().read(id: id, userId: null),
      'user_content_preferences': (c, id) async {
        final item = await c
            .read<DataRepository<UserContentPreferences>>()
            .read(id: id, userId: null);
        if (_isPrivileged(c)) return item;
        final lang = c.read<SupportedLanguage>();
        // Localize nested SavedHeadlineFilters
        final localizedFilters = item.savedHeadlineFilters
            .map((f) => LocalizationUtils.localizeSavedHeadlineFilter(f, lang))
            .toList();
        return item.copyWith(savedHeadlineFilters: localizedFilters);
      },
      'remote_config': (c, id) =>
          c.read<DataRepository<RemoteConfig>>().read(id: id, userId: null),
      'in_app_notification': (c, id) async {
        return c.read<DataRepository<InAppNotification>>().read(
          id: id,
          userId: null,
        );
      },
      'push_notification_device': (c, id) =>
          c.read<DataRepository<PushNotificationDevice>>().read(
            id: id,
            userId: null,
          ),
      'engagement': (c, id) =>
          c.read<DataRepository<Engagement>>().read(id: id, userId: null),
      'report': (c, id) =>
          c.read<DataRepository<Report>>().read(id: id, userId: null),
      'app_review': (c, id) =>
          c.read<DataRepository<AppReview>>().read(id: id, userId: null),
      'kpi_card_data': (c, id) async {
        final item = await c.read<DataRepository<KpiCardData>>().read(
          id: id,
          userId: null,
        );
        if (_isPrivileged(c)) return item;
        final lang = c.read<SupportedLanguage>();
        return LocalizationUtils.localizeKpiCardData(item, lang);
      },
      'chart_card_data': (c, id) async {
        final item = await c.read<DataRepository<ChartCardData>>().read(
          id: id,
          userId: null,
        );
        if (_isPrivileged(c)) return item;
        final lang = c.read<SupportedLanguage>();
        return LocalizationUtils.localizeChartCardData(item, lang);
      },
      'ranked_list_card_data': (c, id) async {
        final item = await c.read<DataRepository<RankedListCardData>>().read(
          id: id,
          userId: null,
        );
        if (_isPrivileged(c)) return item;
        final lang = c.read<SupportedLanguage>();
        return LocalizationUtils.localizeRankedListCardData(item, lang);
      },
      'user_rewards': (c, id) =>
          c.read<DataRepository<UserRewards>>().read(id: id, userId: null),
      'media_asset': (c, id) =>
          c.read<DataRepository<MediaAsset>>().read(id: id, userId: null),
    });

    // --- Register "Read All" Readers ---
    _allItemsReaders.addAll({
      'headline': (c, uid, f, s, p) async {
        final lang = c.read<SupportedLanguage>();
        final rewrittenSort = LocalizationUtils.rewriteSortOptions(s, lang, [
          'title',
        ]);
        final expandedFilter = LocalizationUtils.rewriteFilterOptions(f, [
          'title',
        ]);
        final response = await c.read<DataRepository<Headline>>().readAll(
          userId: uid,
          filter: expandedFilter,
          sort: rewrittenSort,
          pagination: p,
        );

        final localizedItems = response.items
            .map((i) => LocalizationUtils.localizeHeadline(i, lang))
            .toList();
        return response.copyWith(items: localizedItems);
      },
      'topic': (c, uid, f, s, p) async {
        final lang = c.read<SupportedLanguage>();
        final rewrittenSort = LocalizationUtils.rewriteSortOptions(s, lang, [
          'name',
          'description',
        ]);
        final expandedFilter = LocalizationUtils.rewriteFilterOptions(f, [
          'name',
          'description',
        ]);
        final response = await c.read<DataRepository<Topic>>().readAll(
          userId: uid,
          filter: expandedFilter,
          sort: rewrittenSort,
          pagination: p,
        );
        final localizedItems = response.items
            .map((i) => LocalizationUtils.localizeTopic(i, lang))
            .toList();
        return response.copyWith(items: localizedItems);
      },
      'source': (c, uid, f, s, p) async {
        final lang = c.read<SupportedLanguage>();
        final rewrittenSort = LocalizationUtils.rewriteSortOptions(s, lang, [
          'name',
          'description',
        ]);
        final expandedFilter = LocalizationUtils.rewriteFilterOptions(f, [
          'name',
          'description',
        ]);
        final response = await c.read<DataRepository<Source>>().readAll(
          userId: uid,
          filter: expandedFilter,
          sort: rewrittenSort,
          pagination: p,
        );
        final localizedItems = response.items
            .map((i) => LocalizationUtils.localizeSource(i, lang))
            .toList();
        return response.copyWith(items: localizedItems);
      },
      'country': (c, uid, f, s, p) async {
        final lang = c.read<SupportedLanguage>();
        final rewrittenSort = LocalizationUtils.rewriteSortOptions(s, lang, [
          'name',
        ]);
        final expandedFilter = LocalizationUtils.rewriteFilterOptions(f, [
          'name',
        ]);

        // Sanitize filter: Countries are static metadata and no longer have
        // a 'status' field. We strip it to prevent empty results from
        // generic client-side filtering logic.
        final sanitizedFilter = expandedFilter != null
            ? Map<String, dynamic>.from(expandedFilter)
            : null;
        sanitizedFilter?.remove('status');

        PaginatedResponse<Country> response;

        // Check for special filters that require aggregation.
        if (sanitizedFilter != null &&
            (sanitizedFilter.containsKey('hasActiveSources') ||
                sanitizedFilter.containsKey('hasActiveHeadlines'))) {
          // Use the injected CountryQueryService for complex queries.
          final countryQueryService = c.read<CountryQueryService>();
          response = await countryQueryService.getFilteredCountries(
            filter: sanitizedFilter,
            pagination: p,
            sort: rewrittenSort,
          );
        } else {
          // Fallback to standard readAll if no special filters are present.
          response = await c.read<DataRepository<Country>>().readAll(
            userId: uid,
            filter: sanitizedFilter,
            sort: rewrittenSort,
            pagination: p,
          );
        }

        final localizedItems = response.items
            .map((i) => LocalizationUtils.localizeCountry(i, lang))
            .toList();
        return response.copyWith(items: localizedItems);
      },
      'language': (c, uid, f, s, p) async {
        final lang = c.read<SupportedLanguage>();
        final rewrittenSort = LocalizationUtils.rewriteSortOptions(s, lang, [
          'name',
        ]);
        final expandedFilter = LocalizationUtils.rewriteFilterOptions(f, [
          'name',
        ]);

        // Sanitize filter: Languages are static metadata and no longer have
        // a 'status' field. We strip it to prevent empty results from
        // generic client-side filtering logic.
        final sanitizedFilter = expandedFilter != null
            ? Map<String, dynamic>.from(expandedFilter)
            : null;
        sanitizedFilter?.remove('status');

        final response = await c.read<DataRepository<Language>>().readAll(
          userId: uid,
          filter: sanitizedFilter,
          sort: rewrittenSort,
          pagination: p,
        );
        final localizedItems = response.items
            .map((i) => LocalizationUtils.localizeLanguage(i, lang))
            .toList();
        return response.copyWith(items: localizedItems);
      },
      'user': (c, uid, f, s, p) => c.read<DataRepository<User>>().readAll(
        userId: uid,
        filter: f,
        sort: s,
        pagination: p,
      ),
      'in_app_notification': (c, uid, f, s, p) async {
        final finalFilter = {...?f};
        if (uid != null) {
          finalFilter['userId'] = uid;
        }
        return c.read<DataRepository<InAppNotification>>().readAll(
          userId: null,
          filter: finalFilter,
          sort: s,
          pagination: p,
        );
      },
      'push_notification_device': (c, uid, f, s, p) {
        final finalFilter = {...?f};
        if (uid != null) {
          finalFilter['userId'] = uid;
        }
        return c.read<DataRepository<PushNotificationDevice>>().readAll(
          userId: null,
          filter: finalFilter,
          sort: s,
          pagination: p,
        );
      },
      'engagement': (c, uid, f, s, p) {
        final finalFilter = {...?f};
        if (uid != null) {
          finalFilter['userId'] = uid;
        }
        return c.read<DataRepository<Engagement>>().readAll(
          userId: null,
          filter: finalFilter,
          sort: s,
          pagination: p,
        );
      },
      'report': (c, uid, f, s, p) {
        final finalFilter = {...?f};
        if (uid != null) {
          finalFilter['reporterUserId'] = uid;
        }
        return c.read<DataRepository<Report>>().readAll(
          userId: null,
          filter: finalFilter,
          sort: s,
          pagination: p,
        );
      },
      'app_review': (c, uid, f, s, p) {
        final finalFilter = {...?f};
        if (uid != null) {
          finalFilter['userId'] = uid;
        }
        return c.read<DataRepository<AppReview>>().readAll(
          userId: null,
          filter: finalFilter,
          sort: s,
          pagination: p,
        );
      },
      'kpi_card_data': (c, uid, f, s, p) async {
        final lang = c.read<SupportedLanguage>();
        final expandedFilter = LocalizationUtils.rewriteFilterOptions(f, [
          'label',
        ]);
        final response = await c.read<DataRepository<KpiCardData>>().readAll(
          userId: uid,
          filter: expandedFilter,
          sort: s,
          pagination: p,
        );
        final localizedItems = response.items
            .map((i) => LocalizationUtils.localizeKpiCardData(i, lang))
            .toList();
        return response.copyWith(items: localizedItems);
      },
      'chart_card_data': (c, uid, f, s, p) async {
        final lang = c.read<SupportedLanguage>();
        final expandedFilter = LocalizationUtils.rewriteFilterOptions(f, [
          'label',
        ]);
        final response = await c.read<DataRepository<ChartCardData>>().readAll(
          userId: uid,
          filter: expandedFilter,
          sort: s,
          pagination: p,
        );
        final localizedItems = response.items
            .map((i) => LocalizationUtils.localizeChartCardData(i, lang))
            .toList();
        return response.copyWith(items: localizedItems);
      },
      'ranked_list_card_data': (c, uid, f, s, p) async {
        final lang = c.read<SupportedLanguage>();
        final expandedFilter = LocalizationUtils.rewriteFilterOptions(f, [
          'label',
        ]);
        final response = await c
            .read<DataRepository<RankedListCardData>>()
            .readAll(
              userId: uid,
              filter: expandedFilter,
              sort: s,
              pagination: p,
            );
        final localizedItems = response.items
            .map((i) => LocalizationUtils.localizeRankedListCardData(i, lang))
            .toList();
        return response.copyWith(items: localizedItems);
      },
      'user_rewards': (c, uid, f, s, p) {
        final finalFilter = {...?f};
        if (uid != null) {
          finalFilter['userId'] = uid;
        }
        return c.read<DataRepository<UserRewards>>().readAll(
          userId: null,
          filter: finalFilter,
          sort: s,
          pagination: p,
        );
      },
      'media_asset': (c, uid, f, s, p) =>
          c.read<DataRepository<MediaAsset>>().readAll(
            userId: uid,
            filter: f,
            sort: s,
            pagination: p,
          ),
    });

    // --- Register Item Creators ---
    _itemCreators.addAll({
      'headline': (c, item, uid) async {
        var headlineToCreate = item as Headline;

        // --- ENRICHMENT: Fetch full entities to store all translations ---
        // The client might send a partial snapshot (e.g., only English names).
        // We fetch the authoritative documents from the DB to ensure the
        // embedded objects in the Headline contain ALL supported languages.
        final results = await Future.wait([
          c.read<DataRepository<Source>>().read(id: headlineToCreate.source.id),
          c.read<DataRepository<Topic>>().read(id: headlineToCreate.topic.id),
          c.read<DataRepository<Country>>().read(
            id: headlineToCreate.eventCountry.id,
          ),
        ]);

        headlineToCreate = headlineToCreate.copyWith(
          source: results[0] as Source,
          topic: results[1] as Topic,
          eventCountry: results[2] as Country,
        );

        // If a mediaAssetId is provided on creation, ensure imageUrl is null.
        if (headlineToCreate.mediaAssetId != null) {
          headlineToCreate = headlineToCreate.copyWith(
            imageUrl: const ValueWrapper(null),
          );
        }

        final createdHeadline = await c.read<DataRepository<Headline>>().create(
          item: headlineToCreate,
          userId: uid,
        );

        if (createdHeadline.isBreaking) {
          try {
            final pushNotificationService = c.read<IPushNotificationService>();
            unawaited(
              pushNotificationService.sendBreakingNewsNotification(
                headline: createdHeadline,
              ),
            );
          } catch (e, s) {
            _log.severe('Failed to send breaking news notification: $e', e, s);
          }
        }
        return createdHeadline;
      },
      'topic': (c, item, uid) async {
        var topicToCreate = item as Topic;

        // If a mediaAssetId is provided on creation, ensure iconUrl is null.
        if (topicToCreate.mediaAssetId != null) {
          topicToCreate = topicToCreate.copyWith(
            iconUrl: const ValueWrapper(null),
          );
        }

        return c.read<DataRepository<Topic>>().create(
          item: topicToCreate,
          userId: uid,
        );
      },
      'source': (c, item, uid) async {
        var sourceToCreate = item as Source;

        // --- ENRICHMENT: Fetch full Country for headquarters ---
        // Ensure the embedded Country object contains all translations, not just
        // the partial snapshot sent by the client.
        final fullHeadquarters = await c.read<DataRepository<Country>>().read(
          id: sourceToCreate.headquarters.id,
        );
        sourceToCreate = sourceToCreate.copyWith(
          headquarters: fullHeadquarters,
        );

        // If a mediaAssetId is provided on creation, ensure logoUrl is null.
        if (sourceToCreate.mediaAssetId != null) {
          sourceToCreate = sourceToCreate.copyWith(
            logoUrl: const ValueWrapper(null),
          );
        }

        return c.read<DataRepository<Source>>().create(
          item: sourceToCreate,
          userId: uid,
        );
      },
      'country': (c, item, uid) => c.read<DataRepository<Country>>().create(
        item: item as Country,
        userId: uid,
      ),
      'language': (c, item, uid) => c.read<DataRepository<Language>>().create(
        item: item as Language,
        userId: uid,
      ),
      'remote_config': (c, item, uid) =>
          c.read<DataRepository<RemoteConfig>>().create(
            item: item as RemoteConfig,
            userId: uid,
          ),
      'push_notification_device': (context, item, uid) async {
        _log.info('Executing custom creator for push_notification_device.');
        final authenticatedUser = context.read<User>();
        final deviceToCreate = item as PushNotificationDevice;

        // Security Check: Ensure the userId in the payload matches the
        // authenticated user's ID. This prevents a user from registering a
        // device on behalf of another user.
        if (deviceToCreate.userId != authenticatedUser.id) {
          _log.warning(
            'Forbidden attempt by user ${authenticatedUser.id} to create a '
            'device for user ${deviceToCreate.userId}.',
          );
          throw const ForbiddenException(
            'You can only register devices for your own account.',
          );
        }

        _log.info(
          'User ${authenticatedUser.id} is registering a new device. '
          'Validation passed.',
        );

        // The validation passed, so we can now safely call the repository.
        // The `uid` (userIdForRepoCall) is passed as null because for
        // user-owned resources, the scoping is handled by the creator logic
        // itself, not a generic filter in the repository.
        return context.read<DataRepository<PushNotificationDevice>>().create(
          item: deviceToCreate,
          userId: null,
        );
      },
      'engagement': (context, item, uid) async {
        _log.info('Executing custom creator for engagement.');
        final authenticatedUser = context.read<User>();
        final userActionLimitService = context.read<UserActionLimitService>();
        final engagementToCreate = item as Engagement;

        // Security Check
        if (engagementToCreate.userId != authenticatedUser.id) {
          throw const ForbiddenException(
            'You can only create engagements for your own account.',
          );
        }

        // Business Logic Check: Ensure a user can only have one engagement
        // per headline to prevent duplicate reactions or comments.
        final engagementRepository = context.read<DataRepository<Engagement>>();
        final existingEngagements = await engagementRepository.readAll(
          filter: {
            'userId': authenticatedUser.id,
            'entityId': engagementToCreate.entityId,
            'entityType': engagementToCreate.entityType.name,
          },
        );

        if (existingEngagements.items.isNotEmpty) {
          _log.warning(
            'User ${authenticatedUser.id} attempted to create a second engagement for entity ${engagementToCreate.entityId}.',
          );
          throw const ConflictException(
            'An engagement for this item already exists.',
          );
        }

        // Limit Check: Delegate to the centralized service.
        await userActionLimitService.checkEngagementCreationLimit(
          user: authenticatedUser,
          engagement: engagementToCreate,
        );

        return context.read<DataRepository<Engagement>>().create(
          item: engagementToCreate,
          userId: null,
        );
      },
      'report': (context, item, uid) async {
        _log.info('Executing custom creator for report.');
        final authenticatedUser = context.read<User>();
        final userActionLimitService = context.read<UserActionLimitService>();
        final reportToCreate = item as Report;

        // Security Check
        if (reportToCreate.reporterUserId != authenticatedUser.id) {
          throw const ForbiddenException(
            'You can only create reports for your own account.',
          );
        }

        // Limit Check
        await userActionLimitService.checkReportCreationLimit(
          user: authenticatedUser,
        );

        return context.read<DataRepository<Report>>().create(item: item);
      },
      'app_review': (context, item, uid) async {
        _log.info('Executing custom creator for app_review.');
        final authenticatedUser = context.read<User>();
        final appReviewToCreate = item as AppReview;

        // Security Check
        if (appReviewToCreate.userId != authenticatedUser.id) {
          throw const ForbiddenException(
            'You can only create app reviews for your own account.',
          );
        }

        // Business Logic Check: Ensure a user can only have one AppReview record.
        // This prevents creating multiple feedback entries, adhering to the
        // intended "create once, update later" workflow.
        final appReviewRepository = context.read<DataRepository<AppReview>>();
        final existingReviews = await appReviewRepository.readAll(
          filter: {'userId': authenticatedUser.id},
        );

        if (existingReviews.items.isNotEmpty) {
          _log.warning(
            'User ${authenticatedUser.id} attempted to create a second AppReview record.',
          );
          throw const ConflictException(
            'An app review record already exists.',
          );
        }

        return context.read<DataRepository<AppReview>>().create(item: item);
      },
    });

    // --- Register Item Updaters ---
    _itemUpdaters.addAll({
      'headline': (c, id, item, uid) async {
        // Fetch RAW item to ensure we have all translations before merging
        final rawHeadline = await c.read<DataRepository<Headline>>().read(
          id: id,
        );
        final requestedUpdateHeadline = item as Headline;

        // 1. Merge Translations
        var finalHeadline = requestedUpdateHeadline.copyWith(
          title: LocalizationUtils.mergeTranslations(
            rawHeadline.title,
            requestedUpdateHeadline.title,
          ),
        );

        // 2. Handle Media Asset Logic
        // If the mediaAssetId is being changed to a new non-null value,
        // we should nullify the imageUrl to ensure the webhook-populated URL is used.
        if (requestedUpdateHeadline.mediaAssetId != rawHeadline.mediaAssetId &&
            requestedUpdateHeadline.mediaAssetId != null) {
          finalHeadline = finalHeadline.copyWith(
            imageUrl: const ValueWrapper(null),
          );
        }

        return c.read<DataRepository<Headline>>().update(
          id: id,
          item: finalHeadline,
          userId: uid,
        );
      },
      'topic': (c, id, item, uid) async {
        final rawTopic = await c.read<DataRepository<Topic>>().read(id: id);
        final requestedUpdateTopic = item as Topic;

        var finalTopic = requestedUpdateTopic.copyWith(
          name: LocalizationUtils.mergeTranslations(
            rawTopic.name,
            requestedUpdateTopic.name,
          ),
          description: LocalizationUtils.mergeTranslations(
            rawTopic.description,
            requestedUpdateTopic.description,
          ),
        );

        if (requestedUpdateTopic.mediaAssetId != rawTopic.mediaAssetId &&
            requestedUpdateTopic.mediaAssetId != null) {
          finalTopic = finalTopic.copyWith(iconUrl: const ValueWrapper(null));
        }

        return c.read<DataRepository<Topic>>().update(
          id: id,
          item: finalTopic,
          userId: uid,
        );
      },
      'source': (c, id, item, uid) async {
        final rawSource = await c.read<DataRepository<Source>>().read(id: id);
        final requestedUpdateSource = item as Source;

        var finalSource = requestedUpdateSource.copyWith(
          name: LocalizationUtils.mergeTranslations(
            rawSource.name,
            requestedUpdateSource.name,
          ),
          description: LocalizationUtils.mergeTranslations(
            rawSource.description,
            requestedUpdateSource.description,
          ),
        );

        if (requestedUpdateSource.mediaAssetId != rawSource.mediaAssetId &&
            requestedUpdateSource.mediaAssetId != null) {
          finalSource = finalSource.copyWith(
            logoUrl: const ValueWrapper(null),
          );
        }

        return c.read<DataRepository<Source>>().update(
          id: id,
          item: finalSource,
          userId: uid,
        );
      },
      'country': (c, id, item, uid) => c.read<DataRepository<Country>>().update(
        id: id,
        item: item as Country,
        userId: uid,
      ),
      'language': (c, id, item, uid) =>
          c.read<DataRepository<Language>>().update(
            id: id,
            item: item as Language,
            userId: uid,
          ),
      // Custom updater for the 'user' model. This logic is critical for
      // security and architectural consistency.
      //
      // It enforces the following rules:
      // 1. Admins can ONLY update a user's `role` and `tier`.
      // 2. Regular users can ONLY update their own `name` and `photoUrl`.
      //
      // This logic correctly handles a full `User` object in the request body,
      // aligning with the DataRepository contract. It works by comparing the
      // incoming `User` object from the request (`requestedUpdateUser`) with
      // the current state of the user in the database (`userToUpdate`), which
      // is pre-fetched by middleware. It then verifies that the *only* fields
      // that have changed are ones the authenticated user is permitted to
      // modify.
      'user': (context, id, item, uid) async {
        _log.info('Executing custom updater for user ID: $id.');
        final permissionService = context.read<PermissionService>();
        final authenticatedUser = context.read<User>();
        final userToUpdate = context.read<FetchedItem<dynamic>>().data as User;
        final requestBody = item as Map<String, dynamic>;
        final requestedUpdateUser = User.fromJson(requestBody);

        // --- State Comparison Logic ---
        if (permissionService.isAdmin(authenticatedUser)) {
          _log.finer(
            'Admin user ${authenticatedUser.id} is updating user $id.',
          );

          // Create a version of the original user with only the fields an
          // admin is allowed to change applied from the request.
          final permissibleUpdate = userToUpdate.copyWith(
            role: requestedUpdateUser.role,
            tier: requestedUpdateUser.tier,
          );

          // If the user from the request is not identical to the one with
          // only permissible changes, it means an unauthorized field was
          // modified.
          if (requestedUpdateUser != permissibleUpdate) {
            _log.warning(
              'Admin ${authenticatedUser.id} attempted to update unauthorized '
              'fields for user $id.',
            );
            throw const ForbiddenException(
              'Administrators can only update "role" and "tier" via this '
              'endpoint.',
            );
          }
          _log.finer('Admin update for user $id validation passed.');
        } else {
          _log.finer(
            'Regular user ${authenticatedUser.id} is updating their own profile.',
          );

          // Create a version of the original user with only the fields a
          // regular user is allowed to change applied from the request.
          // Regular users can only update 'name', 'photoUrl', and 'mediaAssetId'.
          // Critical fields like 'email', 'role', 'tier', 'isAnonymous' are
          // immutable via this endpoint.
          final permissibleUpdate = userToUpdate.copyWith(
            name: ValueWrapper(requestedUpdateUser.name),
            photoUrl: ValueWrapper(requestedUpdateUser.photoUrl),
            mediaAssetId: ValueWrapper(requestedUpdateUser.mediaAssetId),
          );

          // If the user from the request is not identical to the one with
          // only permissible changes, it means an unauthorized field was
          // modified.
          if (requestedUpdateUser != permissibleUpdate) {
            _log.warning(
              'User ${authenticatedUser.id} attempted to update unauthorized fields.',
            );
            throw const ForbiddenException(
              'You can only update "name", "photoUrl", and "mediaAssetId" via this endpoint.',
            );
          }
          _log.finer(
            'Regular user update for user $id validation passed.',
          );
        }

        _log.info(
          'User update validation passed. Calling repository with full object.',
        );
        // The validation passed, so we can now safely pass the full User
        // object from the request to the repository, honoring the contract.
        return context.read<DataRepository<User>>().update(
          id: id,
          item: requestedUpdateUser,
          userId: uid,
        );
      },
      'app_settings': (c, id, item, uid) =>
          c.read<DataRepository<AppSettings>>().update(
            id: id,
            item: item as AppSettings,
            userId: uid,
          ),
      'user_context': (c, id, item, uid) =>
          c.read<DataRepository<UserContext>>().update(
            id: id,
            item: item as UserContext,
            userId: uid,
          ),
      'user_content_preferences': (context, id, item, uid) async {
        _log.info(
          'Executing custom updater for user_content_preferences ID: $id.',
        );
        final authenticatedUser = context.read<User>();
        final permissionService = context.read<PermissionService>();
        final userActionLimitService = context.read<UserActionLimitService>();
        final userContentPreferencesRepository = context
            .read<DataRepository<UserContentPreferences>>();

        // Fetch RAW preferences to merge SavedHeadlineFilter names
        final rawPreferences = await userContentPreferencesRepository.read(
          id: id,
        );
        final preferencesToUpdate = item as UserContentPreferences;

        // Merge SavedHeadlineFilters names
        // We iterate through the incoming filters and look for a match in the
        // raw existing filters. If found, we merge the name map.
        final mergedFilters = preferencesToUpdate.savedHeadlineFilters.map((
          incomingFilter,
        ) {
          final existingFilter = rawPreferences.savedHeadlineFilters.firstWhere(
            (f) => f.id == incomingFilter.id,
            orElse: () => incomingFilter,
          );

          // If it's the same filter (by ID), merge the name
          if (existingFilter.id == incomingFilter.id) {
            return incomingFilter.copyWith(
              name: LocalizationUtils.mergeTranslations(
                existingFilter.name,
                incomingFilter.name,
              ),
            );
          }
          return incomingFilter;
        }).toList();

        final finalPreferences = preferencesToUpdate.copyWith(
          savedHeadlineFilters: mergedFilters,
        );

        // 2. Validate all limits using the consolidated service method.
        if (permissionService.hasPermission(
          authenticatedUser,
          Permissions.userPreferenceBypassLimits,
        )) {
          _log.info(
            'User ${authenticatedUser.id} has bypass permission. Skipping limit checks.',
          );
        } else {
          await userActionLimitService.checkUserContentPreferencesLimits(
            user: authenticatedUser,
            updatedPreferences: finalPreferences,
          );
        }

        // 3. Enrich the preferences with full entity data (translations).
        // This ensures that followed items and saved filters contain all
        // supported languages, not just the one active on the client.
        final enrichedPreferences = await _enrichPreferences(
          context,
          finalPreferences,
        );

        _log.info(
          'Enrichment complete for user ${authenticatedUser.id}. Proceeding with update.',
        );
        return userContentPreferencesRepository.update(
          id: id,
          item: enrichedPreferences,
        );
      },
      'remote_config': (c, id, item, uid) =>
          c.read<DataRepository<RemoteConfig>>().update(
            id: id,
            item: item as RemoteConfig,
            userId: uid,
          ),
      'in_app_notification': (c, id, item, uid) async {
        return c.read<DataRepository<InAppNotification>>().update(
          id: id,
          item: item as InAppNotification,
        );
      },
      'engagement': (context, id, item, uid) async {
        _log.info('Executing custom updater for engagement ID: $id.');
        final existingEngagement =
            context.read<FetchedItem<dynamic>>().data as Engagement;
        final requestedUpdate = item as Engagement;

        var finalUpdate = requestedUpdate;

        // Check if the comment section is being updated
        if (requestedUpdate.comment != null) {
          final newContent = requestedUpdate.comment!.content;
          final oldContent = existingEngagement.comment?.content;

          // If content has changed (or is new), revert status to pendingReview
          if (newContent != oldContent) {
            _log.info(
              'Comment content changed for engagement $id. Reverting status to pendingReview.',
            );
            finalUpdate = finalUpdate.copyWith(
              comment: ValueWrapper(
                requestedUpdate.comment!.copyWith(
                  status: ModerationStatus.pendingReview,
                ),
              ),
            );
          } else if (existingEngagement.comment != null) {
            // If content hasn't changed, ensure the status remains as it was
            // (preventing users from manually setting it to resolved)
            finalUpdate = finalUpdate.copyWith(
              comment: ValueWrapper(
                requestedUpdate.comment!.copyWith(
                  status: existingEngagement.comment!.status,
                ),
              ),
            );
          }
        }

        return context.read<DataRepository<Engagement>>().update(
          id: id,
          item: finalUpdate,
        );
      },
      'report': (c, id, item, uid) => c.read<DataRepository<Report>>().update(
        id: id,
        item: item as Report,
      ),
      'app_review': (c, id, item, uid) =>
          c.read<DataRepository<AppReview>>().update(
            id: id,
            item: item as AppReview,
          ),
    });

    // --- Register Item Deleters ---
    _itemDeleters.addAll({
      'headline': (context, id, uid) async {
        _log.info('Executing custom deleter for headline ID: $id.');
        final headlineRepository = context.read<DataRepository<Headline>>();
        final mediaAssetRepository = context.read<DataRepository<MediaAsset>>();
        final storageService = context.read<IStorageService>();

        final headline = await headlineRepository.read(id: id);

        if (headline.imageUrl != null && headline.imageUrl!.isNotEmpty) {
          unawaited(
            cleanupMediaAssetByUrl(
              url: headline.imageUrl,
              mediaAssetRepository: mediaAssetRepository,
              storageService: storageService,
            ).catchError(
              (Object e, StackTrace s) =>
                  _log.severe('Asset cleanup failed.', e, s),
            ),
          );
        }

        await headlineRepository.delete(id: id, userId: uid);
      },
      'topic': (context, id, uid) async {
        _log.info('Executing custom deleter for topic ID: $id.');
        final topicRepository = context.read<DataRepository<Topic>>();
        final mediaAssetRepository = context.read<DataRepository<MediaAsset>>();
        final storageService = context.read<IStorageService>();

        final topic = await topicRepository.read(id: id);
        if (topic.iconUrl != null && topic.iconUrl!.isNotEmpty) {
          unawaited(
            cleanupMediaAssetByUrl(
              url: topic.iconUrl,
              mediaAssetRepository: mediaAssetRepository,
              storageService: storageService,
            ).catchError(
              (Object e, StackTrace s) =>
                  _log.severe('Asset cleanup failed.', e, s),
            ),
          );
        }
        await topicRepository.delete(id: id, userId: uid);
      },
      'source': (context, id, uid) async {
        _log.info('Executing custom deleter for source ID: $id.');
        final sourceRepository = context.read<DataRepository<Source>>();
        final mediaAssetRepository = context.read<DataRepository<MediaAsset>>();
        final storageService = context.read<IStorageService>();

        final source = await sourceRepository.read(id: id);
        if (source.logoUrl != null && source.logoUrl!.isNotEmpty) {
          unawaited(
            cleanupMediaAssetByUrl(
              url: source.logoUrl,
              mediaAssetRepository: mediaAssetRepository,
              storageService: storageService,
            ).catchError(
              (Object e, StackTrace s) =>
                  _log.severe('Asset cleanup failed.', e, s),
            ),
          );
        }
        await sourceRepository.delete(id: id, userId: uid);
      },
      'country': (c, id, uid) =>
          c.read<DataRepository<Country>>().delete(id: id, userId: uid),
      'language': (c, id, uid) =>
          c.read<DataRepository<Language>>().delete(id: id, userId: uid),
      'app_settings': (c, id, uid) =>
          c.read<DataRepository<AppSettings>>().delete(id: id, userId: uid),
      'user_content_preferences': (c, id, uid) =>
          c.read<DataRepository<UserContentPreferences>>().delete(
            id: id,
            userId: uid,
          ),
      'remote_config': (c, id, uid) =>
          c.read<DataRepository<RemoteConfig>>().delete(id: id, userId: uid),
      'push_notification_device': (c, id, uid) =>
          c.read<DataRepository<PushNotificationDevice>>().delete(
            id: id,
            userId: uid,
          ),
      'in_app_notification': (c, id, uid) =>
          c.read<DataRepository<InAppNotification>>().delete(
            id: id,
            userId: uid,
          ),
      'engagement': (c, id, uid) =>
          c.read<DataRepository<Engagement>>().delete(id: id, userId: uid),
      'report': (c, id, uid) =>
          c.read<DataRepository<Report>>().delete(id: id, userId: uid),
      'app_review': (c, id, uid) =>
          c.read<DataRepository<AppReview>>().delete(id: id, userId: uid),
      'media_asset': (context, id, uid) async {
        _log.info('Executing custom deleter for media_asset ID: $id.');
        final storageService = context.read<IStorageService>();
        final mediaAssetRepository = context.read<DataRepository<MediaAsset>>();

        // First, fetch the asset to get its status and storage path.
        final assetToDelete = await mediaAssetRepository.read(id: id);

        // 1. If the asset was successfully uploaded, delete the corresponding
        // file from the cloud storage provider.
        if (assetToDelete.status == MediaAssetStatus.completed) {
          try {
            await storageService.deleteObject(
              storagePath: assetToDelete.storagePath,
            );
            _log.info(
              'Deleted file from cloud storage: ${assetToDelete.storagePath}',
            );
          } catch (e, s) {
            _log.warning(
              'Failed to delete file from cloud storage, but proceeding with DB deletion.',
              e,
              s,
            );
          }
        }

        // 2. Delete the database record.
        await mediaAssetRepository.delete(id: id);
        _log.info('Deleted MediaAsset record from database: $id');
      },
    });
  }

  /// Determines if the current user requires raw, unlocalized data.
  ///
  /// We use [PermissionService.hasAnyPermission] to check for the
  /// [Permissions.dashboardLogin] capability. This covers both Administrators
  /// (who have all permissions) and Publishers (who are explicitly granted
  /// dashboard access), ensuring both can access the full translation maps
  /// required for the CMS editor.
  bool _isPrivileged(RequestContext context) {
    final user = context.read<User?>();
    if (user == null) return false;
    return context.read<PermissionService>().hasAnyPermission(
      user,
      {Permissions.dashboardLogin},
    );
  }

  /// Enriches a [UserContentPreferences] object by replacing partial embedded
  /// entities with their full, multi-language versions fetched from the DB.
  ///
  /// This is critical for the "Ingestion-Time Enrichment" pattern. It ensures
  /// that even if the client sends a partial snapshot (e.g., a Topic with only
  /// the English name), the stored preference record will contain the full
  /// Topic document with all translations.
  Future<UserContentPreferences> _enrichPreferences(
    RequestContext context,
    UserContentPreferences prefs,
  ) async {
    // 1. Collect all unique IDs to fetch
    final topicIds = <String>{...prefs.followedTopics.map((e) => e.id)};
    final sourceIds = <String>{...prefs.followedSources.map((e) => e.id)};
    final countryIds = <String>{...prefs.followedCountries.map((e) => e.id)};
    final headlineIds = <String>{...prefs.savedHeadlines.map((e) => e.id)};

    for (final filter in prefs.savedHeadlineFilters) {
      topicIds.addAll(filter.criteria.topics.map((e) => e.id));
      sourceIds.addAll(filter.criteria.sources.map((e) => e.id));
      countryIds.addAll(filter.criteria.countries.map((e) => e.id));
    }

    // 2. Batch Fetch Helper
    Future<Map<String, T>> fetchMap<T>(
      DataRepository<T> repo,
      Set<String> ids,
    ) async {
      if (ids.isEmpty) return {};
      // Use readAll with $in for efficient batch retrieval.
      // We assume reasonable limits on user preferences (enforced by limits config).
      final result = await repo.readAll(
        filter: {
          '_id': {r'$in': ids.toList()},
        },
        pagination: PaginationOptions(limit: ids.length),
      );
      return {for (final item in result.items) (item as dynamic).id: item};
    }

    // 3. Execute Fetches in Parallel
    final results = await Future.wait([
      fetchMap(context.read<DataRepository<Topic>>(), topicIds),
      fetchMap(context.read<DataRepository<Source>>(), sourceIds),
      fetchMap(context.read<DataRepository<Country>>(), countryIds),
      fetchMap(context.read<DataRepository<Headline>>(), headlineIds),
    ]);

    final topicMap = results[0] as Map<String, Topic>;
    final sourceMap = results[1] as Map<String, Source>;
    final countryMap = results[2] as Map<String, Country>;
    final headlineMap = results[3] as Map<String, Headline>;

    // 4. Re-assemble Preferences with Enriched Data
    List<T> enrichList<T>(List<T> partials, Map<String, T> fullMap) {
      return partials.map((p) => fullMap[(p as dynamic).id] ?? p).toList();
    }

    final enrichedFilters = prefs.savedHeadlineFilters.map((filter) {
      return filter.copyWith(
        criteria: filter.criteria.copyWith(
          topics: enrichList(filter.criteria.topics, topicMap),
          sources: enrichList(filter.criteria.sources, sourceMap),
          countries: enrichList(filter.criteria.countries, countryMap),
        ),
      );
    }).toList();

    return prefs.copyWith(
      followedTopics: enrichList(prefs.followedTopics, topicMap),
      followedSources: enrichList(prefs.followedSources, sourceMap),
      followedCountries: enrichList(prefs.followedCountries, countryMap),
      savedHeadlines: enrichList(prefs.savedHeadlines, headlineMap),
      savedHeadlineFilters: enrichedFilters,
    );
  }
}
