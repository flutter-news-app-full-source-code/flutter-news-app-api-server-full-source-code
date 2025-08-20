import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:logging/logging.dart';

/// {@template country_service}
/// A service responsible for retrieving country data, including specialized
/// lists like countries associated with headlines or sources.
///
/// This service leverages database aggregation for efficient data retrieval
/// and includes basic in-memory caching to optimize performance for frequently
/// requested lists.
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

  // In-memory caches for frequently accessed lists.
  // These should be cleared periodically in a real-world application
  // or invalidated upon data changes. For this scope, simple caching is used.
  List<Country>? _cachedEventCountries;
  List<Country>? _cachedHeadquarterCountries;

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
    if (_cachedEventCountries != null) {
      _log.finer('Returning cached event countries.');
      return _cachedEventCountries!;
    }

    _log.finer('Fetching distinct event countries via aggregation.');
    try {
      final pipeline = [
        {
          r'$match': {
            'status': ContentStatus.active.name,
            'eventCountry.id': {r'$exists': true},
          },
        },
        {
          r'$group': {
            '_id': r'$eventCountry.id',
            'country': {r'$first': r'$eventCountry'},
          },
        },
        {
          r'$replaceRoot': {'newRoot': r'$country'},
        },
      ];

      final distinctCountriesJson = await _headlineRepository.aggregate(
        pipeline: pipeline,
      );

      final distinctCountries = distinctCountriesJson
          .map(Country.fromJson)
          .toList();

      _cachedEventCountries = distinctCountries;
      _log.info(
        'Successfully fetched and cached ${distinctCountries.length} '
        'event countries.',
      );
      return distinctCountries;
    } catch (e, s) {
      _log.severe('Failed to fetch event countries via aggregation.', e, s);
      throw OperationFailedException('Failed to retrieve event countries: $e');
    }
  }

  /// Fetches a distinct list of countries that are referenced as
  /// `headquarters` in sources.
  ///
  /// Uses MongoDB aggregation to efficiently get distinct country IDs
  /// and then fetches the full Country objects. Results are cached.
  Future<List<Country>> _getHeadquarterCountries() async {
    if (_cachedHeadquarterCountries != null) {
      _log.finer('Returning cached headquarter countries.');
      return _cachedHeadquarterCountries!;
    }

    _log.finer('Fetching distinct headquarter countries via aggregation.');
    try {
      final pipeline = [
        {
          r'$match': {
            'status': ContentStatus.active.name,
            'headquarters.id': {r'$exists': true},
          },
        },
        {
          r'$group': {
            '_id': r'$headquarters.id',
            'country': {r'$first': r'$headquarters'},
          },
        },
        {
          r'$replaceRoot': {'newRoot': r'$country'},
        },
      ];

      final distinctCountriesJson = await _sourceRepository.aggregate(
        pipeline: pipeline,
      );

      final distinctCountries = distinctCountriesJson
          .map(Country.fromJson)
          .toList();

      _cachedHeadquarterCountries = distinctCountries;
      _log.info(
        'Successfully fetched and cached ${distinctCountries.length} '
        'headquarter countries.',
      );
      return distinctCountries;
    } catch (e, s) {
      _log.severe(
        'Failed to fetch headquarter countries via aggregation.',
        e,
        s,
      );
      throw OperationFailedException(
        'Failed to retrieve headquarter countries: $e',
      );
    }
  }
}
