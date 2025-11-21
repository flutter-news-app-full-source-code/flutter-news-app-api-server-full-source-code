import 'dart:async';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/country_query_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/dashboard_summary_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/push_notification_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/user_preference_limit_service.dart';
import 'package:logging/logging.dart';

// --- Typedefs for Data Operations ---

/// A function that fetches a single item by its ID.
typedef ItemFetcher =
    Future<dynamic> Function(RequestContext context, String id);

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
    Future<void> Function(RequestContext context, String id, String? userId);

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
      'headline': (c, id) =>
          c.read<DataRepository<Headline>>().read(id: id, userId: null),
      'topic': (c, id) =>
          c.read<DataRepository<Topic>>().read(id: id, userId: null),
      'source': (c, id) =>
          c.read<DataRepository<Source>>().read(id: id, userId: null),
      'country': (c, id) =>
          c.read<DataRepository<Country>>().read(id: id, userId: null),
      'language': (c, id) =>
          c.read<DataRepository<Language>>().read(id: id, userId: null),
      'user': (c, id) =>
          c.read<DataRepository<User>>().read(id: id, userId: null),
      'user_app_settings': (c, id) =>
          c.read<DataRepository<UserAppSettings>>().read(id: id, userId: null),
      'user_content_preferences': (c, id) => c
          .read<DataRepository<UserContentPreferences>>()
          .read(id: id, userId: null),
      'remote_config': (c, id) =>
          c.read<DataRepository<RemoteConfig>>().read(id: id, userId: null),
      'dashboard_summary': (c, id) =>
          c.read<DashboardSummaryService>().getSummary(),
      'in_app_notification': (c, id) => c
          .read<DataRepository<InAppNotification>>()
          .read(id: id, userId: null),
      'push_notification_device': (c, id) => c
          .read<DataRepository<PushNotificationDevice>>()
          .read(id: id, userId: null),
    });

    // --- Register "Read All" Readers ---
    _allItemsReaders.addAll({
      'headline': (c, uid, f, s, p) => c
          .read<DataRepository<Headline>>()
          .readAll(userId: uid, filter: f, sort: s, pagination: p),
      'topic': (c, uid, f, s, p) => c.read<DataRepository<Topic>>().readAll(
        userId: uid,
        filter: f,
        sort: s,
        pagination: p,
      ),
      'source': (c, uid, f, s, p) => c.read<DataRepository<Source>>().readAll(
        userId: uid,
        filter: f,
        sort: s,
        pagination: p,
      ),
      'country': (c, uid, f, s, p) async {
        // Check for special filters that require aggregation.
        if (f != null &&
            (f.containsKey('hasActiveSources') ||
                f.containsKey('hasActiveHeadlines'))) {
          // Use the injected CountryQueryService for complex queries.
          final countryQueryService = c.read<CountryQueryService>();
          return countryQueryService.getFilteredCountries(
            filter: f,
            pagination: p,
            sort: s,
          );
        }
        // Fallback to standard readAll if no special filters are present.
        return c.read<DataRepository<Country>>().readAll(
          userId: uid,
          filter: f,
          sort: s,
          pagination: p,
        );
      },
      'language': (c, uid, f, s, p) => c
          .read<DataRepository<Language>>()
          .readAll(userId: uid, filter: f, sort: s, pagination: p),
      'user': (c, uid, f, s, p) => c.read<DataRepository<User>>().readAll(
        userId: uid,
        filter: f,
        sort: s,
        pagination: p,
      ),
      'in_app_notification': (c, uid, f, s, p) =>
          c.read<DataRepository<InAppNotification>>().readAll(
            userId: uid,
            filter: f,
            sort: s,
            pagination: p,
          ),
    });

    // --- Register Item Creators ---
    _itemCreators.addAll({
      'headline': (c, item, uid) async {
        final createdHeadline = await c.read<DataRepository<Headline>>().create(
          item: item as Headline,
          userId: uid,
        );

        // If the created headline is marked as breaking news, trigger the
        // push notification service. The service itself contains all the
        // logic for fetching subscribers and sending notifications.
        //
        // CRITICAL: This is a "fire-and-forget" operation. We do NOT `await`
        // the result. The API response for creating the headline should return
        // immediately, while the notification service runs in the background.
        // The service itself is responsible for its own internal error logging.
        // We wrap this in a try-catch to prevent any unexpected synchronous
        // error from crashing the headline creation process.
        if (createdHeadline.isBreaking) {
          try {
            final pushNotificationService = c.read<IPushNotificationService>();
            unawaited(
              pushNotificationService.sendBreakingNewsNotification(
                headline: createdHeadline,
              ),
            );
            _log.info(
              'Successfully dispatched breaking news notification for headline: ${createdHeadline.id}',
            );
          } catch (e, s) {
            _log.severe('Failed to send breaking news notification: $e', e, s);
          }
        }
        return createdHeadline;
      },
      'topic': (c, item, uid) => c.read<DataRepository<Topic>>().create(
        item: item as Topic,
        userId: uid,
      ),
      'source': (c, item, uid) => c.read<DataRepository<Source>>().create(
        item: item as Source,
        userId: uid,
      ),
      'country': (c, item, uid) => c.read<DataRepository<Country>>().create(
        item: item as Country,
        userId: uid,
      ),
      'language': (c, item, uid) => c.read<DataRepository<Language>>().create(
        item: item as Language,
        userId: uid,
      ),
      'remote_config': (c, item, uid) => c
          .read<DataRepository<RemoteConfig>>()
          .create(item: item as RemoteConfig, userId: uid),
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
    });

    // --- Register Item Updaters ---
    _itemUpdaters.addAll({
      'headline': (c, id, item, uid) => c
          .read<DataRepository<Headline>>()
          .update(id: id, item: item as Headline, userId: uid),
      'topic': (c, id, item, uid) => c.read<DataRepository<Topic>>().update(
        id: id,
        item: item as Topic,
        userId: uid,
      ),
      'source': (c, id, item, uid) => c.read<DataRepository<Source>>().update(
        id: id,
        item: item as Source,
        userId: uid,
      ),
      'country': (c, id, item, uid) => c.read<DataRepository<Country>>().update(
        id: id,
        item: item as Country,
        userId: uid,
      ),
      'language': (c, id, item, uid) => c
          .read<DataRepository<Language>>()
          .update(id: id, item: item as Language, userId: uid),
      // Custom updater for the 'user' model. This logic is critical for
      // security and architectural consistency.
      //
      // It enforces the following rules:
      // 1. Admins can ONLY update a user's `appRole` and `dashboardRole`.
      // 2. Regular users can ONLY update their own `feedDecoratorStatus`.
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
            appRole: requestedUpdateUser.appRole,
            dashboardRole: requestedUpdateUser.dashboardRole,
          );

          // If the user from the request is not identical to the one with
          // only permissible changes, it means an unauthorized field was
          // modified.
          if (requestedUpdateUser != permissibleUpdate) {
            _log.warning(
              'Admin ${authenticatedUser.id} attempted to update unauthorized fields for user $id.',
            );
            throw const ForbiddenException(
              'Administrators can only update "appRole" and "dashboardRole" via this endpoint.',
            );
          }
          _log.finer('Admin update for user $id validation passed.');
        } else {
          _log.finer(
            'Regular user ${authenticatedUser.id} is updating their own profile.',
          );

          // Create a version of the original user with only the fields a
          // regular user is allowed to change applied from the request.
          final permissibleUpdate = userToUpdate.copyWith(
            feedDecoratorStatus: requestedUpdateUser.feedDecoratorStatus,
          );

          // If the user from the request is not identical to the one with
          // only permissible changes, it means an unauthorized field was
          // modified.
          if (requestedUpdateUser != permissibleUpdate) {
            _log.warning(
              'User ${authenticatedUser.id} attempted to update unauthorized fields.',
            );
            throw const ForbiddenException(
              'You can only update "feedDecoratorStatus" via this endpoint.',
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
      'user_app_settings': (c, id, item, uid) => c
          .read<DataRepository<UserAppSettings>>()
          .update(id: id, item: item as UserAppSettings, userId: uid),
      'user_content_preferences': (context, id, item, uid) async {
        _log.info(
          'Executing custom updater for user_content_preferences ID: $id.',
        );
        final authenticatedUser = context.read<User>();
        final permissionService = context.read<PermissionService>();
        final userPreferenceLimitService = context
            .read<UserPreferenceLimitService>();
        final userContentPreferencesRepository = context
            .read<DataRepository<UserContentPreferences>>();

        final preferencesToUpdate = item as UserContentPreferences;

        // 2. Validate all limits using the consolidated service method.
        // The service validates the entire proposed state. We first check
        // if the user has permission to bypass these limits.
        if (permissionService.hasPermission(
          authenticatedUser,
          Permissions.userPreferenceBypassLimits,
        )) {
          _log.info(
            'User ${authenticatedUser.id} has bypass permission. Skipping limit checks.',
          );
        } else {
          await userPreferenceLimitService.checkUserContentPreferencesLimits(
            user: authenticatedUser,
            updatedPreferences: preferencesToUpdate,
          );
        }

        // 3. If all checks pass, proceed with the update.
        _log.info(
          'All preference validations passed for user ${authenticatedUser.id}. '
          'Proceeding with update.',
        );
        return userContentPreferencesRepository.update(
          id: id,
          item: preferencesToUpdate,
        );
      },
      'remote_config': (c, id, item, uid) => c
          .read<DataRepository<RemoteConfig>>()
          .update(id: id, item: item as RemoteConfig, userId: uid),
    });

    // --- Register Item Deleters ---
    _itemDeleters.addAll({
      'headline': (c, id, uid) =>
          c.read<DataRepository<Headline>>().delete(id: id, userId: uid),
      'topic': (c, id, uid) =>
          c.read<DataRepository<Topic>>().delete(id: id, userId: uid),
      'source': (c, id, uid) =>
          c.read<DataRepository<Source>>().delete(id: id, userId: uid),
      'country': (c, id, uid) =>
          c.read<DataRepository<Country>>().delete(id: id, userId: uid),
      'language': (c, id, uid) =>
          c.read<DataRepository<Language>>().delete(id: id, userId: uid),
      'user_app_settings': (c, id, uid) =>
          c.read<DataRepository<UserAppSettings>>().delete(id: id, userId: uid),
      'user_content_preferences': (c, id, uid) => c
          .read<DataRepository<UserContentPreferences>>()
          .delete(id: id, userId: uid),
      'remote_config': (c, id, uid) =>
          c.read<DataRepository<RemoteConfig>>().delete(id: id, userId: uid),
      'push_notification_device': (c, id, uid) => c
          .read<DataRepository<PushNotificationDevice>>()
          .delete(id: id, userId: uid),
      'in_app_notification': (c, id, uid) => c
          .read<DataRepository<InAppNotification>>()
          .delete(id: id, userId: uid),
    });
  }
}
