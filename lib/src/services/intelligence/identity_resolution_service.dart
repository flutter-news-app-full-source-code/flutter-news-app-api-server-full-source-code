import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// The result of a person resolution operation, including statistics.
typedef PersonResolutionResult = ({
  List<Person> persons,
  int createdCount,
  int reusedCount,
});

/// {@template identity_resolution_service}
/// Resolves extracted names into persistent [Person] entities.
///
/// This service implements the "Extract-Search-Link" pattern:
/// 1. Search for an existing Person using a case-insensitive text query.
/// 2. If found, return the ID.
/// 3. If not found, create a new [Person].
/// {@endtemplate}
class IdentityResolutionService {
  /// {@macro identity_resolution_service}
  IdentityResolutionService({
    required DataRepository<Person> personRepository,
    required Logger log,
  }) : _personRepository = personRepository,
       _log = log;

  final DataRepository<Person> _personRepository;
  final Logger _log;

  /// Resolves a list of raw names into a list of full [Person] entities.
  Future<PersonResolutionResult> resolvePersons(
    List<Person> extractions,
  ) async {
    if (extractions.isEmpty) {
      return (persons: <Person>[], createdCount: 0, reusedCount: 0);
    }

    final extractionNames = extractions
        .map((e) => e.name[SupportedLanguage.en] ?? 'Unknown')
        .toList();

    _log.info('Resolving identities for: $extractionNames');
    final resolved = <Person>[];
    final batchCache = <String, Person>{};
    var createdCount = 0;
    var reusedCount = 0;

    for (final extraction in extractions) {
      final enName = extraction.name[SupportedLanguage.en];
      if (enName == null) continue;

      // 0. Check Batch Cache (Prevents race conditions within the same run)
      final cacheKey = enName.trim().toLowerCase();
      if (batchCache.containsKey(cacheKey)) {
        _log.finer('Batch Cache Hit: Reusing resolved person for "$enName"');
        resolved.add(batchCache[cacheKey]!);
        reusedCount++;
        continue;
      }

      try {
        // 1. Search existing (case-insensitive fuzzy match)
        final response = await _personRepository.readAll(
          filter: {'q': enName},
          pagination: const PaginationOptions(limit: 1),
        );

        if (response.items.isNotEmpty) {
          final existing = response.items.first;
          batchCache[cacheKey] = existing;
          resolved.add(existing);
          reusedCount++;
          continue;
        }

        // 2. Create new (Automation Policy: All created as active)
        final newPerson = await _createNewPerson(extraction);
        batchCache[cacheKey] = newPerson;
        resolved.add(newPerson);
        createdCount++;
      } catch (e, s) {
        _log.severe('Failed to resolve identity for: ${extraction.name}', e, s);
        // We don't block the whole process if one person fails.
      }
    }

    return (
      persons: resolved,
      createdCount: createdCount,
      reusedCount: reusedCount,
    );
  }

  Future<Person> _createNewPerson(Person extraction) async {
    final enName = extraction.name[SupportedLanguage.en] ?? 'Unknown';
    _log.info('No match for "$enName". Creating new persistent entity.');

    // Generate a valid database ID and keep the AI-generated localized data.
    final person = extraction.copyWith(
      id: ObjectId().oid,
      status: ContentStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      return await _personRepository.create(item: person);
    } on ConflictException {
      // Handle race conditions where another worker created the person
      final retry = await _personRepository.readAll(
        filter: {'q': enName},
        pagination: const PaginationOptions(limit: 1),
      );
      return retry.items.first;
    }
  }
}
