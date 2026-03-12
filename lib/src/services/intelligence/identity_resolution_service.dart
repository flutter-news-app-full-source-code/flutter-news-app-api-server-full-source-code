import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

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
  Future<List<Person>> resolvePersons(List<String> names) async {
    if (names.isEmpty) return const [];

    _log.info('Resolving identities for names: $names');
    final resolved = <Person>[];

    for (final name in names) {
      try {
        // 1. Search existing (case-insensitive fuzzy match)
        final response = await _personRepository.readAll(
          filter: {'q': name},
          pagination: const PaginationOptions(limit: 1),
        );

        if (response.items.isNotEmpty) {
          _log.fine(
            'Identity match found for: $name -> ${response.items.first.id}',
          );
          resolved.add(response.items.first);
          continue;
        }

        // 2. Create new (Automation Policy: All created as active)
        final newPerson = await _createNewPerson(name);
        resolved.add(newPerson);
      } catch (e, s) {
        _log.severe('Failed to resolve identity for: $name', e, s);
        // We don't block the whole process if one person fails.
      }
    }

    return resolved;
  }

  Future<Person> _createNewPerson(String name) async {
    _log.info('No match for "$name". Creating new persistent entity.');

    // We assume English as the primary name key for auto-created items.
    final person = Person(
      id: ObjectId().oid,
      name: {SupportedLanguage.en: name},
      description: const {
        SupportedLanguage.en: 'Automatically identified figure.',
      },
      // Status is handled via metadata or defaults to active in MongoDB client
    );

    try {
      return await _personRepository.create(item: person);
    } on ConflictException {
      // Handle race conditions where another worker created the person
      final retry = await _personRepository.readAll(
        filter: {'q': name},
        pagination: const PaginationOptions(limit: 1),
      );
      return retry.items.first;
    }
  }
}
