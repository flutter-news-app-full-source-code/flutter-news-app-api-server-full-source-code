import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:veritai_api/src/services/intelligence/identity_resolution_service.dart';

import '../../helpers/test_helpers.dart';

class MockPersonRepository extends Mock implements DataRepository<Person> {}

class MockLogger extends Mock implements Logger {}

void main() {
  late IdentityResolutionService service;
  late MockPersonRepository mockRepo;
  late MockLogger mockLogger;

  setUpAll(() {
    registerSharedFallbackValues();
    registerFallbackValue(const PaginationOptions());
    registerFallbackValue(
      Person(
        id: 'fallback',
        name: const {},
        description: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      ),
    );
  });

  setUp(() {
    mockRepo = MockPersonRepository();
    mockLogger = MockLogger();
    service = IdentityResolutionService(
      personRepository: mockRepo,
      log: mockLogger,
    );
  });

  group('IdentityResolutionService', () {
    test('returns empty list for empty input', () async {
      final result = await service.resolvePersons([]);
      expect(result.persons, isEmpty);
      verifyNever(() => mockRepo.readAll(filter: any(named: 'filter')));
    });

    test(
      'deduplicates identical names within the same batch (Batch Cache)',
      () async {
        final existing = Person(
          id: 'p1',
          name: const {SupportedLanguage.en: 'Elon Musk'},
          description: const {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
        );

        when(
          () => mockRepo.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [existing],
            cursor: null,
            hasMore: false,
          ),
        );

        final input = [
          Person(
            id: 'temp1',
            name: const {SupportedLanguage.en: 'Elon Musk'},
            description: const {},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
          Person(
            id: 'temp2',
            name: const {
              SupportedLanguage.en: '  ELON MUSK  ',
            }, // Test normalization
            description: const {},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
        ];

        final result = await service.resolvePersons(input);

        expect(result.persons, hasLength(2));
        expect(result.persons[0].id, existing.id);
        expect(result.persons[1].id, existing.id);
        expect(result.reusedCount, 2);

        // Verification: The repository was only called ONCE for the search
        // because the second item hit the batchCache.
        verify(
          () => mockRepo.readAll(
            filter: {'q': 'Elon Musk'},
            pagination: any(named: 'pagination'),
          ),
        ).called(1);
      },
    );

    test('returns existing person if found', () async {
      final existing = Person(
        id: 'existing-1',
        name: const {SupportedLanguage.en: 'John Doe'},
        description: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      );

      when(
        () => mockRepo.readAll(
          filter: {'q': 'John Doe'},
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer(
        (_) async => PaginatedResponse(
          items: [existing],
          cursor: null,
          hasMore: false,
        ),
      );

      final result = await service.resolvePersons(
        [
          Person(
            id: 'temp',
            name: const {SupportedLanguage.en: 'John Doe'},
            description: const {},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
        ],
      );

      expect(result.persons, hasLength(1));
      expect(result.persons.first.id, existing.id);
      expect(result.reusedCount, 1);
      expect(result.createdCount, 0);
      verifyNever(() => mockRepo.create(item: any(named: 'item')));
    });

    test('creates new person if not found', () async {
      when(
        () => mockRepo.readAll(
          filter: any(named: 'filter'),
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer(
        (_) async => const PaginatedResponse(
          items: [],
          cursor: null,
          hasMore: false,
        ),
      );

      when(
        () => mockRepo.create(item: any(named: 'item')),
      ).thenAnswer(
        (invocation) async => invocation.namedArguments[#item] as Person,
      );

      final result = await service.resolvePersons(
        [
          Person(
            id: 'temp',
            name: const {SupportedLanguage.en: 'Jane Doe'},
            description: const {SupportedLanguage.en: 'CEO'},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
        ],
      );

      expect(result.persons, hasLength(1));
      expect(result.persons.first.name[SupportedLanguage.en], 'Jane Doe');
      expect(result.createdCount, 1);
      expect(result.reusedCount, 0);
      verify(() => mockRepo.create(item: any(named: 'item'))).called(1);
    });

    test('retries read on ConflictException (Race Condition)', () async {
      // First read: Not found
      when(
        () => mockRepo.readAll(
          filter: any(named: 'filter'),
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer(
        (_) async => const PaginatedResponse(
          items: [],
          cursor: null,
          hasMore: false,
        ),
      );

      // Create attempt: Fails with Conflict (someone else created it)
      when(
        () => mockRepo.create(item: any(named: 'item')),
      ).thenThrow(const ConflictException('Duplicate'));

      // Retry logic calls readAll again... this time we simulate it finding the item
      // NOTE: Since mocktail mocks by call count order is tricky, we can assume
      // the implementation calls readAll again.
      // For simplicity, we just verify create was called and exception handled.
      // To properly mock the *second* call to readAll returning a value, we'd need more complex mock setup.
      // Here we expect the *mocked* retry logic in the service to fire.

      // In the implementation: catch Conflict -> retry readAll.
      // We will let the second readAll call return the list (reuses the mock above? No, mocktail returns same).
      // Actually, if the first readAll returns empty, the retry will also return empty with this setup, causing crash.
      // We need to change the mock to return empty first, then populated.

      final existing = Person(
        id: 'p1',
        name: const {SupportedLanguage.en: 'Jane Doe'},
        description: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ContentStatus.active,
      );

      var readCallCount = 0;
      when(
        () => mockRepo.readAll(
          filter: any(named: 'filter'),
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer((_) async {
        readCallCount++;
        if (readCallCount == 1) {
          return const PaginatedResponse(
            items: [],
            cursor: null,
            hasMore: false,
          );
        }
        return PaginatedResponse(
          items: [existing],
          cursor: null,
          hasMore: false,
        );
      });

      final result = await service.resolvePersons(
        [
          Person(
            id: 'temp',
            name: const {SupportedLanguage.en: 'Jane Doe'},
            description: const {},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
        ],
      );

      expect(result.persons, hasLength(1));
      expect(result.persons.first.id, 'p1');
      verify(() => mockRepo.create(item: any(named: 'item'))).called(1);
      verify(
        () => mockRepo.readAll(
          filter: any(named: 'filter'),
          pagination: any(named: 'pagination'),
        ),
      ).called(2);
    });
  });
}
