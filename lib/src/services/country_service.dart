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
  _CacheEntry<List<Country>>? _cachedEventCountries;
  _CacheEntry<List<Country>>? _cachedHeadquarterCountries;

  // Futures to hold in-flight aggregation requests to prevent cache stampedes.
  Future<List<Country>>? _eventCountriesFuture;
  Future<List<Country>>? _headquarterCountriesFuture;

  /// Retrieves a list of countries based on the provided filter.
  ///
  /// Supports filtering by 'usage' to get countries that are either
  /// 'eventCountry' in headlines or 'headquarters' in sources.
  /// If no specific usage filter is provided, it returns all active countries.
  ///
  /// - [filter]: An optional map containing query parameters.
  ///   Expected keys:
  ///   - `'usage'`: String, can be 'eventCountry' or 'headquarters'.
  ///
  /// Throws [BadRequestException] if an unsupported usage filter is provided.
  /// Throws [OperationFailedException] for internal errors during data fetch.
  Future<List<Country>> getCountries(Map<String, dynamic>? filter) async {
    _log.info('Fetching countries with filter: $filter');

    final usage = filter?['usage'] as String?;

    if (usage == null || usage.isEmpty) {
      _log.fine('No usage filter provided. Fetching all active countries.');
      return _getAllCountries();
    }

    switch (usage) {
      case 'eventCountry':
        _log.fine('Fetching countries used as event countries in headlines.');
        return _getEventCountries();
      case 'headquarters':
        _log.fine('Fetching countries used as headquarters in sources.');
        return _getHeadquarterCountries();
      default:
        _log.warning('Unsupported country usage filter: "$usage"');
        throw BadRequestException(
          'Unsupported country usage filter: "$usage". '
          'Supported values are "eventCountry" and "headquarters".',
        );
    }
  }

  /// Fetches all active countries from the repository.
  Future<List<Country>> _getAllCountries() async {
    _log.finer('Retrieving all active countries from repository.');
    try {
      final response = await _countryRepository.readAll(
        filter: {'status': ContentStatus.active.name},
      );
      return response.items;
    } catch (e, s) {
      _log.severe('Failed to fetch all countries.', e, s);
      throw OperationFailedException('Failed to retrieve all countries: $e');
    }
  }

  /// Fetches a distinct list of countries that are referenced as
  /// `eventCountry` in headlines.
  ///
  /// Uses MongoDB aggregation to efficiently get distinct country IDs
  /// and then fetches the full Country objects. Results are cached.
  Future<List<Country>> _getEventCountries() async {
    if (_cachedEventCountries != null && _cachedEventCountries!.isValid()) {
      _log.finer('Returning cached event countries.');
      return _cachedEventCountries!.data;
    }
    // Atomically assign the future if no fetch is in progress.
    _eventCountriesFuture ??= _fetchAndCacheEventCountries();
    return _eventCountriesFuture!;
  }

  /// Fetches a distinct list of countries that are referenced as
  /// `headquarters` in sources.
  ///
  /// Uses MongoDB aggregation to efficiently get distinct country IDs
  /// and then fetches the full Country objects. Results are cached.
  Future<List<Country>> _getHeadquarterCountries() async {
    if (_cachedHeadquarterCountries != null &&
        _cachedHeadquarterCountries!.isValid()) {
      _log.finer('Returning cached headquarter countries.');
      return _cachedHeadquarterCountries!.data;
    }
    // Atomically assign the future if no fetch is in progress.
    _headquarterCountriesFuture ??= _fetchAndCacheHeadquarterCountries();
    return _headquarterCountriesFuture!;
  }

  /// Helper method to fetch and cache distinct event countries.
  Future<List<Country>> _fetchAndCacheEventCountries() async {
    _log.finer('Fetching distinct event countries via aggregation.');
    try {
      final distinctCountries = await _getDistinctCountriesFromAggregation(
        repository: _headlineRepository,
        fieldName: 'eventCountry',
      );
      _cachedEventCountries = _CacheEntry(
        distinctCountries,
        DateTime.now().add(_cacheDuration),
      );
      _log.info(
        'Successfully fetched and cached ${distinctCountries.length} '
        'event countries.',
      );
      return distinctCountries;
    } finally {
      // Clear the future once the operation is complete (success or error).
      _eventCountriesFuture = null;
    }
  }

  /// Helper method to fetch and cache distinct headquarter countries.
  Future<List<Country>> _fetchAndCacheHeadquarterCountries() async {
    _log.finer('Fetching distinct headquarter countries via aggregation.');
    try {
      final distinctCountries = await _getDistinctCountriesFromAggregation(
        repository: _sourceRepository,
        fieldName: 'headquarters',
      );
      _cachedHeadquarterCountries = _CacheEntry(
        distinctCountries,
        DateTime.now().add(_cacheDuration),
      );
      _log.info(
        'Successfully fetched and cached ${distinctCountries.length} '
        'headquarter countries.',
      );
      return distinctCountries;
    } finally {
      // Clear the future once the operation is complete (success or error).
      _headquarterCountriesFuture = null;
    }
  }

  /// Helper method to fetch a distinct list of countries from a given
  /// repository and field name using MongoDB aggregation.
  ///
  /// - [repository]: The [DataRepository] to perform the aggregation on.
  /// - [fieldName]: The name of the field within the documents that contains
  ///   the country object (e.g., 'eventCountry', 'headquarters').
  ///
  /// Throws [OperationFailedException] for internal errors during data fetch.
  Future<List<Country>> _getDistinctCountriesFromAggregation<T extends FeedItem>({
    required DataRepository<T> repository,
    required String fieldName,
  }) async {
    _log.finer('Fetching distinct countries for field "$fieldName" via aggregation.');
    try {
      final pipeline = [
        {
          r'$match': {
            'status': ContentStatus.active.name,
            '$fieldName.id': {r'$exists': true},
          },
        },
        {
          r'$group': {
            '_id': '\$$fieldName.id',
            'country': {r'$first': '\$$fieldName'},
          },
        },
        {
          r'$replaceRoot': {'newRoot': r'$country'},
        },
      ];

      final distinctCountriesJson = await repository.aggregate(
        pipeline: pipeline,
      );

      final distinctCountries = distinctCountriesJson
          .map(Country.fromJson)
          .toList();

      _log.info(
        'Successfully fetched ${distinctCountries.length} distinct countries '
        'for field "$fieldName".',
      );
      return distinctCountries;
    } catch (e, s) {
      _log.severe(
        'Failed to fetch distinct countries for field "$fieldName".',
        e,
        s,
      );
      throw OperationFailedException(
        'Failed to retrieve distinct countries for field "$fieldName": $e',
      );
    }
  }
}
