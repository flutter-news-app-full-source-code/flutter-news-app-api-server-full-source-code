import 'dart:async';
import 'dart:collection'; // Added for SplayTreeMap
import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:logging/logging.dart';

/// {@template country_query_service}
/// A service responsible for executing complex queries on country data,
/// including filtering by active sources and headlines, and supporting
/// compound filters with text search.
///
/// This service also implements robust in-memory caching with a configurable
/// Time-To-Live (TTL) to optimize performance for frequently requested queries.
/// {@endtemplate}
class CountryQueryService {
  /// {@macro country_query_service}
  CountryQueryService({
    required DataRepository<Country> countryRepository,
    required Logger log,
    Duration cacheDuration = const Duration(minutes: 15),
  })  : _countryRepository = countryRepository,
        _log = log,
        _cacheDuration = cacheDuration {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupCache();
    });
    _log.info(
      'CountryQueryService initialized with cache duration: $cacheDuration',
    );
  }
  final DataRepository<Country> _countryRepository;
  final Logger _log;
  final Duration _cacheDuration;

  final Map<String, ({PaginatedResponse<Country> data, DateTime expiry})>
      _cache = {};
  Timer? _cleanupTimer;
  bool _isDisposed = false;

  /// Retrieves a paginated list of countries based on the provided filters,
  /// including special filters for active sources and headlines, and text search.
  ///
  /// This method supports compound filtering by combining `q` (text search),
  /// `hasActiveSources`, `hasActiveHeadlines`, and other standard filters.
  /// Results are cached to improve performance.
  ///
  /// - [filter]: A map containing query conditions. Special keys like
  ///   `hasActiveSources` and `hasActiveHeadlines` trigger aggregation logic.
  ///   The `q` key triggers a text search on country names.
  /// - [pagination]: Optional pagination parameters.
  /// - [sort]: Optional sorting options.
  ///
  /// Throws [OperationFailedException] for unexpected errors during query
  /// execution or cache operations.
  Future<PaginatedResponse<Country>> getFilteredCountries({
    required Map<String, dynamic> filter,
    PaginationOptions? pagination,
    List<SortOption>? sort,
  }) async {
    if (_isDisposed) {
      _log.warning('Attempted to query on disposed service.');
      throw const OperationFailedException('Service is disposed.');
    }

    final cacheKey = _generateCacheKey(filter, pagination, sort);
    final cachedEntry = _cache[cacheKey];

    if (cachedEntry != null && DateTime.now().isBefore(cachedEntry.expiry)) {
      _log.finer('Returning cached result for key: $cacheKey');
      return cachedEntry.data;
    }

    _log.info('Executing new query for countries with filter: $filter');
    try {
      final pipeline = _buildAggregationPipeline(filter, pagination, sort);
      final aggregationResult = await _countryRepository.aggregate(
        pipeline: pipeline,
      );

      // MongoDB aggregation returns a list of maps. We need to convert these
      // back into Country objects.
      final countries = aggregationResult.map(Country.fromJson).toList();

      // For aggregation queries, pagination and hasMore need to be handled
      // manually if not directly supported by the aggregation stages.
      // For simplicity, we'll assume the aggregation pipeline handles limit/skip
      // and we'll determine hasMore based on if we fetched more than the limit.
      final limit = pagination?.limit ?? countries.length;
      final hasMore = countries.length > limit;
      final paginatedCountries = countries.take(limit).toList();

      final response = PaginatedResponse<Country>(
        items: paginatedCountries,
        cursor: null, // Aggregation doesn't typically return a cursor directly
        hasMore: hasMore,
      );

      _cache[cacheKey] = (
        data: response,
        expiry: DateTime.now().add(_cacheDuration),
      );
      _log.finer('Cached new result for key: $cacheKey');

      return response;
    } on HttpException {
      rethrow; // Propagate known HTTP exceptions
    } catch (e, s) {
      _log.severe('Error fetching filtered countries: $e', e, s);
      throw OperationFailedException(
        'Failed to retrieve filtered countries: $e',
      );
    }
  }

  /// Builds the MongoDB aggregation pipeline based on the provided filters.
  List<Map<String, Object>> _buildAggregationPipeline(
    Map<String, dynamic> filter,
    PaginationOptions? pagination,
    List<SortOption>? sort,
  ) {
    final pipeline = <Map<String, Object>>[];
    final compoundMatchStages = <Map<String, dynamic>>[];

    // --- Stage 1: Initial Match for active status, text search, and other filters ---
    // All countries should be active by default for these queries
    compoundMatchStages.add({'status': ContentStatus.active.name});

    // Handle `q` (text search) filter
    final qValue = filter['q'];
    if (qValue is String && qValue.isNotEmpty) {
      compoundMatchStages.add({
        r'$text': {r'$search': qValue},
      });
    }

    // Handle other standard filters
    filter.forEach((key, value) {
      if (key != 'q' &&
          key != 'hasActiveSources' &&
          key != 'hasActiveHeadlines') {
        compoundMatchStages.add({key: value});
      }
    });

    // Combine all compound match stages and add to pipeline first for efficiency
    if (compoundMatchStages.isNotEmpty) {
      pipeline.add({
        r'$match': {r'$and': compoundMatchStages},
      });
    }

    // --- Stage 2: Handle `hasActiveSources` filter ---
    if (filter['hasActiveSources'] == true) {
      // This lookup uses a sub-pipeline to filter for active sources *before*
      // joining, which is more efficient than a post-join match.
      pipeline.add({
        r'$lookup': {
          'from': 'sources',
          'let': {'countryId': r'$_id'},
          'pipeline': [
            {
              r'$match': {
                r'$expr': {
                  r'$eq': [r'$headquarters._id', r'$$countryId'],
                },
                'status': ContentStatus.active.name,
              },
            },
          ],
          'as': 'matchingSources',
        },
      });
      pipeline.add({
        r'$match': {
          'matchingSources': {r'$ne': <Object>[]},
        },
      });
    }

    // --- Stage 3: Handle `hasActiveHeadlines` filter ---
    if (filter['hasActiveHeadlines'] == true) {
      // This lookup uses a sub-pipeline to filter for active headlines *before*
      // joining, which is more efficient than a post-join match.
      pipeline.add({
        r'$lookup': {
          'from': 'headlines',
          'let': {'countryId': r'$_id'},
          'pipeline': [
            {
              r'$match': {
                r'$expr': {
                  r'$eq': [r'$eventCountry._id', r'$$countryId'],
                },
                'status': ContentStatus.active.name,
              },
            },
          ],
          'as': 'matchingHeadlines',
        },
      });
      pipeline.add({
        r'$match': {
          'matchingHeadlines': {r'$ne': <Object>[]},
        },
      });
    }

    // --- Stage 4: Sorting ---
    if (sort != null && sort.isNotEmpty) {
      final sortStage = <String, Object>{};
      for (final option in sort) {
        sortStage[option.field] = option.order == SortOrder.asc ? 1 : -1;
      }
      pipeline.add({r'$sort': sortStage});
    }

    // --- Stage 5: Pagination (Skip and Limit) ---
    if (pagination?.cursor != null) {
      // For cursor-based pagination, we'd typically need a more complex
      // aggregation that sorts by the cursor field and then skips.
      // For simplicity, this example assumes offset-based pagination or
      // that the client handles cursor logic.
      _log.warning(
        'Cursor-based pagination is not fully implemented for aggregation '
        'queries in CountryQueryService. Only limit/skip is supported.',
      );
    }
    if (pagination?.limit != null) {
      // Fetch one more than the limit to determine 'hasMore'
      pipeline.add({r'$limit': pagination!.limit! + 1});
    }

    // --- Stage 6: Final Projection ---
    // Project to match the Country model's JSON structure.
    // The $lookup stages add fields ('matchingSources', 'matchingHeadlines')
    // that are not part of the Country model, so we project only the fields
    // that are part of the model to ensure clean deserialization.
    pipeline.add({
      r'$project': {
        '_id': 0, // Exclude _id
        'id': {r'$toString': r'$_id'}, // Map _id back to id
        'isoCode': r'$isoCode',
        'name': r'$name',
        'flagUrl': r'$flagUrl',
        'createdAt': r'$createdAt',
        'updatedAt': r'$updatedAt',
        'status': r'$status',
      },
    });

    return pipeline;
  }

  /// Generates a unique, canonical cache key from the query parameters.
  ///
  /// A canonical key is essential for effective caching. If two different
  /// sets of parameters represent the same logical query (e.g., filters in a
  /// different order), they must produce the exact same cache key.
  ///
  /// This implementation achieves this by:
  /// 1. Using a [SplayTreeMap] for the `filter` map, which automatically
  ///    sorts the filters by their keys.
  /// 2. Sorting the `sort` options by their field names.
  /// 3. Combining these sorted structures with pagination details into a
  ///    standard map.
  /// 4. Encoding the final map into a JSON string, which serves as the
  ///    reliable and unique cache key.
  String _generateCacheKey(
    Map<String, dynamic> filter,
    PaginationOptions? pagination,
    List<SortOption>? sort,
  ) {
    final sortedFilter = SplayTreeMap<String, dynamic>.from(filter);
    final List<SortOption>? sortedSort;
    if (sort != null) {
      sortedSort = List<SortOption>.from(sort)
        ..sort((a, b) => a.field.compareTo(b.field));
    } else {
      sortedSort = null;
    }

    final keyData = {
      'filter': sortedFilter,
      'pagination': {'cursor': pagination?.cursor, 'limit': pagination?.limit},
      'sort': sortedSort?.map((s) => '${s.field}:${s.order.name}').toList(),
    };
    return json.encode(keyData);
  }

  /// Cleans up expired entries from the in-memory cache.
  void _cleanupCache() {
    if (_isDisposed) return;

    final now = DateTime.now();
    final expiredKeys = <String>[];

    _cache.forEach((key, value) {
      if (now.isAfter(value.expiry)) {
        expiredKeys.add(key);
      }
    });

    if (expiredKeys.isNotEmpty) {
      expiredKeys.forEach(_cache.remove);
      _log.info('Cleaned up ${expiredKeys.length} expired cache entries.');
    } else {
      _log.finer('Cache cleanup ran, no expired entries found.');
    }
  }

  /// Disposes of resources, specifically the periodic cache cleanup timer.
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _cleanupTimer?.cancel();
      _cache.clear();
      _log.info('CountryQueryService disposed.');
    }
  }
}
