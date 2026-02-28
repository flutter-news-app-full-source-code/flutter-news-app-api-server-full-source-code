import 'package:core/core.dart';
import 'package:logging/logging.dart';

/// {@template content_enrichment_service}
/// A generic service responsible for the "Ingestion-Time Enrichment" pattern.
///
/// This service ensures data consistency for any domain entity that embeds
/// other entities containing translatable properties. When a parent entity is
/// created or updated, this service intercepts the operation to replace partial
/// embedded snapshots (which may only contain one language) with the
/// authoritative, fully-translated documents fetched from the database.
///
/// This guarantees that:
/// 1.  **Data Completeness:** Stored documents always contain the full set of
///     translations for their embedded dependencies.
/// 2.  **Read Efficiency:** Localization occurs in-memory during read operations,
///     maintaining O(1) read performance without requiring "join" queries.
/// {@endtemplate}
class ContentEnrichmentService {
  /// {@macro content_enrichment_service}
  const ContentEnrichmentService({
    required DataRepository<Source> sourceRepository,
    required DataRepository<Topic> topicRepository,
    required DataRepository<Country> countryRepository,
    required DataRepository<Headline> headlineRepository,
    required Logger log,
  }) : _sourceRepository = sourceRepository,
       _topicRepository = topicRepository,
       _countryRepository = countryRepository,
       _headlineRepository = headlineRepository,
       _log = log;

  final DataRepository<Source> _sourceRepository;
  final DataRepository<Topic> _topicRepository;
  final DataRepository<Country> _countryRepository;
  final DataRepository<Headline> _headlineRepository;
  final Logger _log;

  /// Enriches a [Headline] by fetching the full [Source], [Topic], and
  /// [Country] entities.
  Future<Headline> enrichHeadline(Headline headline) async {
    _log.info('Enriching headline: ${headline.id}');
    final results = await Future.wait([
      _sourceRepository.read(id: headline.source.id),
      _topicRepository.read(id: headline.topic.id),
      _countryRepository.read(id: headline.eventCountry.id),
    ]);

    return headline.copyWith(
      source: results[0] as Source,
      topic: results[1] as Topic,
      eventCountry: results[2] as Country,
    );
  }

  /// Enriches a [Source] by fetching the full [Country] for its headquarters.
  Future<Source> enrichSource(Source source) async {
    _log.info('Enriching source: ${source.id}');
    final fullHeadquarters = await _countryRepository.read(
      id: source.headquarters.id,
    );
    return source.copyWith(headquarters: fullHeadquarters);
  }

  /// Enriches [UserContentPreferences] by replacing partial embedded entities
  /// in followed lists and saved filters with their full, multi-language versions.
  Future<UserContentPreferences> enrichUserContentPreferences(
    UserContentPreferences prefs,
  ) async {
    _log.info('Enriching preferences for user: ${prefs.id}');

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

    // 2. Execute Fetches in Parallel
    final results = await Future.wait([
      _fetchMap(_topicRepository, topicIds),
      _fetchMap(_sourceRepository, sourceIds),
      _fetchMap(_countryRepository, countryIds),
      _fetchMap(_headlineRepository, headlineIds),
    ]);

    final topicMap = results[0] as Map<String, Topic>;
    final sourceMap = results[1] as Map<String, Source>;
    final countryMap = results[2] as Map<String, Country>;
    final headlineMap = results[3] as Map<String, Headline>;

    // 3. Re-assemble Preferences with Enriched Data
    final enrichedFilters = prefs.savedHeadlineFilters.map((filter) {
      return filter.copyWith(
        criteria: filter.criteria.copyWith(
          topics: _enrichList(filter.criteria.topics, topicMap),
          sources: _enrichList(filter.criteria.sources, sourceMap),
          countries: _enrichList(filter.criteria.countries, countryMap),
        ),
      );
    }).toList();

    return prefs.copyWith(
      followedTopics: _enrichList(prefs.followedTopics, topicMap),
      followedSources: _enrichList(prefs.followedSources, sourceMap),
      followedCountries: _enrichList(prefs.followedCountries, countryMap),
      savedHeadlines: _enrichList(prefs.savedHeadlines, headlineMap),
      savedHeadlineFilters: enrichedFilters,
    );
  }

  // --- Helpers ---

  /// Batch fetches entities by ID and returns a `Map<ID, Entity>`.
  Future<Map<String, T>> _fetchMap<T>(
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
    return {
      for (final item in result.items) (item as dynamic).id as String: item,
    };
  }

  /// Replaces items in a list with their enriched versions from the map.
  /// If an item is not found in the map (e.g., deleted), it falls back to the
  /// original partial item.
  List<T> _enrichList<T>(List<T> partials, Map<String, T> fullMap) {
    return partials.map((p) {
      final id = (p as dynamic).id;
      if (fullMap.containsKey(id)) {
        return fullMap[id] as T;
      }
      _log.warning(
        'Enrichment warning: Entity $id not found in DB. '
        'Using partial data.',
      );
      return p;
    }).toList();
  }
}
