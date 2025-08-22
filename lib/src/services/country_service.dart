import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:logging/logging.dart';

/// {@template _cache_entry}
/// A simple class to hold cached data along with its expiration time.
/// {@endtemplate}
class _CacheEntry<T> {
  /// {@macro _cache_entry}
  const _CacheEntry(this.data, this.expiry);

  /// The cached data.
  final T data;

  /// The time at which the cached data expires.
  final DateTime expiry;

  /// Checks if the cache entry is still valid (not expired).
  bool isValid() => DateTime.now().isBefore(expiry);
}

/// {@template country_service}
/// A service responsible for retrieving country data, including specialized
/// lists like countries associated with headlines or sources.
///
/// This service leverages database aggregation for efficient data retrieval
/// and includes time-based in-memory caching to optimize performance for
/// frequently requested lists.
/// {@endtemplate}
class CountryService {
  /// {@macro country_service}
  CountryService({
    required DataRepository<Country> countryRepository,
    required DataRepository<Headline> headlineRepository,
    required DataRepository<Source> sourceRepository,
    Logger? logger,
  }) : _countryRepository = countryRepository,
       _headlineRepository = headlineRepository,
       _sourceRepository = sourceRepository,
       _log = logger ?? Logger('CountryService');

  final DataRepository<Country> _countryRepository;
  final DataRepository<Headline> _headlineRepository;
  final DataRepository<Source> _sourceRepository;
  final Logger _log;

  // Cache duration for aggregated country lists (e.g., 1 hour).
  static const Duration _cacheDuration = Duration(hours: 1);

  // In-memory caches for frequently accessed lists with time-based invalidation.
  final Map<String, _CacheEntry<List<Country>>> _cachedEventCountries = {};
  final Map<String, _CacheEntry<List<Country>>> _cachedHeadquarterCountries = {};

  // Futures to hold in-flight aggregation requests to prevent cache stampedes.
  Future<List<Country>>? _eventCountriesFuture;
  Future<List<Country>>? _headquarterCountriesFuture;

  /// Retrieves a list of countries based on the provided filter.
  ///
  /// Supports filtering by 'usage' to get countries that are either
  /// 'eventCountry' in headlines or 'headquarters' in sources.
  /// It also supports filtering by 'name' (full or partial match).
  ///
  /// - [filter]: An optional map containing query parameters.
  ///   Expected keys:
  ///   - `'usage'`: String, can be 'eventCountry' or 'headquarters'.
  ///   - `'name'`: String, a full or partial country name for search.
  ///
  /// Throws [BadRequestException] if an unsupported usage filter is provided.
  /// Throws [OperationFailedException] for internal errors during data fetch.
  Future<List<Country>> getCountries(Map<String, dynamic>? filter) async {
    _log.info('Fetching countries with filter: $filter');

    final usage = filter?['usage'] as String?;
    final name = filter?['name'] as String?;

    Map<String, dynamic>? nameFilter;
    if (name != null && name.isNotEmpty) {
      // Create a case-insensitive regex filter for the name.
      nameFilter = {r'$regex': name, r'$options': 'i'};
    }

    if (usage == null || usage.isEmpty) {
      _log.fine(
        'No usage filter provided. Fetching all active countries '
        'with nameFilter: $nameFilter.',
      );
      return _getAllCountries(nameFilter: nameFilter);
    }

    switch (usage) {
      case 'eventCountry':
        _log.fine(
          'Fetching countries used as event countries in headlines '
          'with nameFilter: $nameFilter.',
        );
        return _getEventCountries(nameFilter: nameFilter);
      case 'headquarters':
        _log.fine(
          'Fetching countries used as headquarters in sources '
          'with nameFilter: $nameFilter.',
        );
        return _getHeadquarterCountries(nameFilter: nameFilter);
      default:
        _log.warning('Unsupported country usage filter: "$usage"');
        throw BadRequestException(
          'Unsupported country usage filter: "$usage". '
          'Supported values are "eventCountry" and "headquarters".',
        );
    }
  }

  /// Fetches all active countries from the repository.
  ///
  /// - [nameFilter]: An optional map containing a regex filter for the country name.
  Future<List<Country>> _getAllCountries({
    Map<String, dynamic>? nameFilter,
  }) async {
    _log.finer(
      'Retrieving all active countries from repository with nameFilter: $nameFilter.',
    );
    try {
      final combinedFilter = <String, dynamic>{
        'status': ContentStatus.active.name,
      };
      if (nameFilter != null && nameFilter.isNotEmpty) {
        combinedFilter.addAll({'name': nameFilter});
      }

      final response = await _countryRepository.readAll(
        filter: combinedFilter,
      );
      return response.items;
    } catch (e, s) {
      _log.severe('Failed to fetch all countries with nameFilter: $nameFilter.', e, s);
      throw OperationFailedException('Failed to retrieve all countries: $e');
    }
  }

  /// Fetches a distinct list of countries that are referenced as
  /// `eventCountry` in headlines.
  ///
  /// Uses MongoDB aggregation to efficiently get distinct country IDs
  /// and then fetches the full Country objects. Results are cached.
  ///
  /// - [nameFilter]: An optional map containing a regex filter for the country name.
  Future<List<Country>> _getEventCountries({
    Map<String, dynamic>? nameFilter,
  }) async {
    final cacheKey = 'eventCountry_${nameFilter ?? 'noFilter'}';
    if (_cachedEventCountries.containsKey(cacheKey) &&
        _cachedEventCountries[cacheKey]!.isValid()) {
      _log.finer('Returning cached event countries for key: $cacheKey.');
      return _cachedEventCountries[cacheKey]!.data;
    }
    // Atomically assign the future if no fetch is in progress,
    // and clear it when the future completes.
    _eventCountriesFuture ??= _fetchAndCacheEventCountries(nameFilter: nameFilter)
        .whenComplete(() => _eventCountriesFuture = null);
    return _eventCountriesFuture!;
  }

  /// Fetches a distinct list of countries that are referenced as
  /// `headquarters` in sources.
  ///
  /// Uses MongoDB aggregation to efficiently get distinct country IDs
  /// and then fetches the full Country objects. Results are cached.
  ///
  /// - [nameFilter]: An optional map containing a regex filter for the country name.
  Future<List<Country>> _getHeadquarterCountries({
    Map<String, dynamic>? nameFilter,
  }) async {
    final cacheKey = 'headquarters_${nameFilter ?? 'noFilter'}';
    if (_cachedHeadquarterCountries.containsKey(cacheKey) &&
        _cachedHeadquarterCountries[cacheKey]!.isValid()) {
      _log.finer('Returning cached headquarter countries for key: $cacheKey.');
      return _cachedHeadquarterCountries[cacheKey]!.data;
    }
    // Atomically assign the future if no fetch is in progress,
    // and clear it when the future completes.
    _headquarterCountriesFuture ??=
        _fetchAndCacheHeadquarterCountries(nameFilter: nameFilter)
            .whenComplete(() => _headquarterCountriesFuture = null);
    return _headquarterCountriesFuture!;
  }

  /// Helper method to fetch and cache distinct event countries.
  ///
  /// - [nameFilter]: An optional map containing a regex filter for the country name.
  Future<List<Country>> _fetchAndCacheEventCountries({
    Map<String, dynamic>? nameFilter,
  }) async {
    _log.finer(
      'Fetching distinct event countries via aggregation with nameFilter: $nameFilter.',
    );
    try {
      final distinctCountries = await _getDistinctCountriesFromAggregation(
        repository: _headlineRepository,
        fieldName: 'eventCountry',
        nameFilter: nameFilter,
      );
      final cacheKey = 'eventCountry_${nameFilter ?? 'noFilter'}';
      _cachedEventCountries[cacheKey] = _CacheEntry(
        distinctCountries,
        DateTime.now().add(_cacheDuration),
      );
      _log.info(
        'Successfully fetched and cached ${distinctCountries.length} '
        'event countries for key: $cacheKey.',
      );
      return distinctCountries;
    } catch (e, s) {
      _log.severe(
        'Failed to fetch distinct event countries via aggregation '
        'with nameFilter: $nameFilter.',
        e,
        s,
      );
      rethrow; // Re-throw the original exception
    }
  }

  /// Helper method to fetch and cache distinct headquarter countries.
  ///
  /// - [nameFilter]: An optional map containing a regex filter for the country name.
  Future<List<Country>> _fetchAndCacheHeadquarterCountries({
    Map<String, dynamic>? nameFilter,
  }) async {
    _log.finer(
      'Fetching distinct headquarter countries via aggregation with nameFilter: $nameFilter.',
    );
    try {
      final distinctCountries = await _getDistinctCountriesFromAggregation(
        repository: _sourceRepository,
        fieldName: 'headquarters',
        nameFilter: nameFilter,
      );
      final cacheKey = 'headquarters_${nameFilter ?? 'noFilter'}';
      _cachedHeadquarterCountries[cacheKey] = _CacheEntry(
        distinctCountries,
        DateTime.now().add(_cacheDuration),
      );
      _log.info(
        'Successfully fetched and cached ${distinctCountries.length} '
        'headquarter countries for key: $cacheKey.',
      );
      return distinctCountries;
    } catch (e, s) {
      _log.severe(
        'Failed to fetch distinct headquarter countries via aggregation '
        'with nameFilter: $nameFilter.',
        e,
        s,
      );
      rethrow; // Re-throw the original exception
    }
  }

  /// Helper method to fetch a distinct list of countries from a given
  /// repository and field name using MongoDB aggregation.
  ///
  /// - [repository]: The [DataRepository] to perform the aggregation on.
  /// - [fieldName]: The name of the field within the documents that contains
  ///   the country object (e.g., 'eventCountry', 'headquarters').
  /// - [nameFilter]: An optional map containing a regex filter for the country name.
  ///
  /// Throws [OperationFailedException] for internal errors during data fetch.
  Future<List<Country>>
  _getDistinctCountriesFromAggregation<T extends FeedItem>({
    required DataRepository<T> repository,
    required String fieldName,
    Map<String, dynamic>? nameFilter,
  }) async {
    _log.finer(
      'Fetching distinct countries for field "$fieldName" via aggregation '
      'with nameFilter: $nameFilter.',
    );
    try {
      final pipeline = <Map<String, Object>>[
        <String, Object>{
          r'$match': <String, Object>{
            'status': ContentStatus.active.name,
            '$fieldName.id': <String, Object>{r'$exists': true},
          },
        },
      ];

      // Add name filter if provided
      if (nameFilter != null && nameFilter.isNotEmpty) {
        pipeline.add(
          <String, Object>{
            r'$match': <String, Object>{'$fieldName.name': nameFilter},
          },
        );
      }

      pipeline.addAll([
        <String, Object>{
          r'$group': <String, Object>{
            '_id': '\$$fieldName.id',
            'country': <String, Object>{r'$first': '\$$fieldName'},
          },
        },
        <String, Object>{
          r'$replaceRoot': <String, Object>{'newRoot': r'$country'},
        },
      ]);

      final distinctCountriesJson = await repository.aggregate(
        pipeline: pipeline,
      );

      final distinctCountries = distinctCountriesJson
          .map(Country.fromJson)
          .toList();

      _log.info(
        'Successfully fetched ${distinctCountries.length} distinct countries '
        'for field "$fieldName" with nameFilter: $nameFilter.',
      );
      return distinctCountries;
    } catch (e, s) {
      _log.severe(
        'Failed to fetch distinct countries for field "$fieldName" '
        'with nameFilter: $nameFilter.',
        e,
        s,
      );
      throw OperationFailedException(
        'Failed to retrieve distinct countries for field "$fieldName": $e',
      );
    }
  }
}
