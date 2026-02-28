import 'package:core/core.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/content_enrichment_service.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockSourceRepository extends Mock implements DataRepository<Source> {}

class MockTopicRepository extends Mock implements DataRepository<Topic> {}

class MockCountryRepository extends Mock implements DataRepository<Country> {}

class MockHeadlineRepository extends Mock implements DataRepository<Headline> {}

void main() {
  group('ContentEnrichmentService', () {
    late MockSourceRepository mockSourceRepo;
    late MockTopicRepository mockTopicRepo;
    late MockCountryRepository mockCountryRepo;
    late MockHeadlineRepository mockHeadlineRepo;
    late ContentEnrichmentService service;

    setUp(() {
      mockSourceRepo = MockSourceRepository();
      mockTopicRepo = MockTopicRepository();
      mockCountryRepo = MockCountryRepository();
      mockHeadlineRepo = MockHeadlineRepository();
      service = ContentEnrichmentService(
        sourceRepository: mockSourceRepo,
        topicRepository: mockTopicRepo,
        countryRepository: mockCountryRepo,
        headlineRepository: mockHeadlineRepo,
        log: Logger('TestContentEnrichmentService'),
      );
    });

    final testCountry = Country(
      id: 'c1',
      isoCode: 'US',
      name: {SupportedLanguage.en: 'USA', SupportedLanguage.es: 'EEUU'},
      flagUrl: 'flag.png',
    );

    final testSource = Source(
      id: 's1',
      name: {SupportedLanguage.en: 'CNN'},
      description: {},
      url: 'url',
      sourceType: SourceType.newsAgency,
      language: SupportedLanguage.en,
      headquarters: testCountry,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
    );

    final testTopic = Topic(
      id: 't1',
      name: {SupportedLanguage.en: 'Tech'},
      description: {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
    );

    final testHeadline = Headline(
      id: 'h1',
      title: {},
      source: testSource,
      eventCountry: testCountry,
      topic: testTopic,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ContentStatus.active,
      isBreaking: false,
      url: 'url',
      imageUrl: 'img',
    );

    test('enrichHeadline fetches and replaces embedded entities', () async {
      when(
        () => mockSourceRepo.read(id: 's1'),
      ).thenAnswer((_) async => testSource);
      when(
        () => mockTopicRepo.read(id: 't1'),
      ).thenAnswer((_) async => testTopic);
      when(
        () => mockCountryRepo.read(id: 'c1'),
      ).thenAnswer((_) async => testCountry);

      // Create a headline with partial data (e.g. missing translations)
      final partialHeadline = testHeadline.copyWith(
        eventCountry: testCountry.copyWith(name: {SupportedLanguage.en: 'USA'}),
      );

      final result = await service.enrichHeadline(partialHeadline);

      expect(
        result.eventCountry.name,
        containsPair(SupportedLanguage.es, 'EEUU'),
      );
      verify(() => mockSourceRepo.read(id: 's1')).called(1);
      verify(() => mockTopicRepo.read(id: 't1')).called(1);
      verify(() => mockCountryRepo.read(id: 'c1')).called(1);
    });

    test('enrichSource fetches and replaces headquarters', () async {
      when(
        () => mockCountryRepo.read(id: 'c1'),
      ).thenAnswer((_) async => testCountry);

      final partialSource = testSource.copyWith(
        headquarters: testCountry.copyWith(name: {SupportedLanguage.en: 'USA'}),
      );

      final result = await service.enrichSource(partialSource);

      expect(
        result.headquarters.name,
        containsPair(SupportedLanguage.es, 'EEUU'),
      );
      verify(() => mockCountryRepo.read(id: 'c1')).called(1);
    });

    test('enrichUserContentPreferences enriches lists and filters', () async {
      final prefs = UserContentPreferences(
        id: 'u1',
        followedCountries: [testCountry],
        followedSources: [testSource],
        followedTopics: [testTopic],
        savedHeadlines: [testHeadline],
        savedHeadlineFilters: [
          SavedHeadlineFilter(
            id: 'f1',
            userId: 'u1',
            name: {},
            criteria: HeadlineFilterCriteria(
              topics: [testTopic],
              sources: [],
              countries: [],
            ),
            isPinned: false,
            deliveryTypes: {},
          ),
        ],
      );

      // Mock batch reads
      when(
        () => mockTopicRepo.readAll(
          filter: any(named: 'filter'),
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer(
        (_) async => PaginatedResponse(
          items: [testTopic],
          cursor: null,
          hasMore: false,
        ),
      );

      when(
        () => mockSourceRepo.readAll(
          filter: any(named: 'filter'),
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer(
        (_) async => PaginatedResponse(
          items: [testSource],
          cursor: null,
          hasMore: false,
        ),
      );

      when(
        () => mockCountryRepo.readAll(
          filter: any(named: 'filter'),
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer(
        (_) async => PaginatedResponse(
          items: [testCountry],
          cursor: null,
          hasMore: false,
        ),
      );

      when(
        () => mockHeadlineRepo.readAll(
          filter: any(named: 'filter'),
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer(
        (_) async => PaginatedResponse(
          items: [testHeadline],
          cursor: null,
          hasMore: false,
        ),
      );

      final result = await service.enrichUserContentPreferences(prefs);

      // Verify interactions
      verify(
        () => mockTopicRepo.readAll(
          filter: any(named: 'filter'),
          pagination: any(named: 'pagination'),
        ),
      ).called(1);

      // Verify structure integrity
      expect(result.followedCountries.first.id, equals(testCountry.id));
      expect(
        result.savedHeadlineFilters.first.criteria.topics.first.id,
        equals(testTopic.id),
      );
    });

    test(
      'enrichUserContentPreferences handles missing entities gracefully',
      () async {
        final prefs = UserContentPreferences(
          id: 'u1',
          followedCountries: [],
          followedSources: [],
          followedTopics: [testTopic], // Topic exists in prefs
          savedHeadlines: [],
          savedHeadlineFilters: [],
        );

        // Mock repo returning empty list (simulating deletion)
        when(
          () => mockTopicRepo.readAll(
            filter: any(named: 'filter'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async =>
              const PaginatedResponse(items: [], cursor: null, hasMore: false),
        );

        final result = await service.enrichUserContentPreferences(prefs);

        // Should fall back to the original partial item
        expect(result.followedTopics.first.id, equals(testTopic.id));
      },
    );
  });
}
