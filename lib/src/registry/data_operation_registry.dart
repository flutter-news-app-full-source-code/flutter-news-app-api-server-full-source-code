import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/country_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/dashboard_summary_service.dart';

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
        final usage = f?['usage'] as String?;
        final name = f?['name'] as String?;

        // If either 'usage' or 'name' filter is present, delegate to CountryService.
        // Sorting and pagination are handled by CountryService for these specialized queries.
        if ((usage != null && usage.isNotEmpty) || (name != null && name.isNotEmpty)) {
          final countryService = c.read<CountryService>();
          final countries = await countryService.getCountries(f);
          return PaginatedResponse<Country>(
            items: countries,
            cursor: null, // No cursor for this type of filtered list
            hasMore: false, // No more items as it's a complete filtered set
          );
        } else {
          // For standard requests without specialized filters, use the repository
          // which supports pagination/sorting.
          return c.read<DataRepository<Country>>().readAll(
                userId: uid,
                filter: f,
                sort: s,
                pagination: p,
              );
        }
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
    });

    // --- Register Item Creators ---
    _itemCreators.addAll({
      'headline': (c, item, uid) => c.read<DataRepository<Headline>>().create(
        item: item as Headline,
        userId: uid,
      ),
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
      'user': (c, id, item, uid) {
        final repo = c.read<DataRepository<User>>();
        final existingUser = c.read<FetchedItem<dynamic>>().data as User;
        final updatedUser = existingUser.copyWith(
          feedDecoratorStatus: (item as User).feedDecoratorStatus,
        );
        return repo.update(id: id, item: updatedUser, userId: uid);
      },
      'user_app_settings': (c, id, item, uid) => c
          .read<DataRepository<UserAppSettings>>()
          .update(id: id, item: item as UserAppSettings, userId: uid),
      'user_content_preferences': (c, id, item, uid) => c
          .read<DataRepository<UserContentPreferences>>()
          .update(id: id, item: item as UserContentPreferences, userId: uid),
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
      'user': (c, id, uid) =>
          c.read<DataRepository<User>>().delete(id: id, userId: uid),
      'user_app_settings': (c, id, uid) =>
          c.read<DataRepository<UserAppSettings>>().delete(id: id, userId: uid),
      'user_content_preferences': (c, id, uid) => c
          .read<DataRepository<UserContentPreferences>>()
          .delete(id: id, userId: uid),
      'remote_config': (c, id, uid) =>
          c.read<DataRepository<RemoteConfig>>().delete(id: id, userId: uid),
    });
  }
}
