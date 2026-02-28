import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/registry/data_operation_registry.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/content_enrichment_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_helpers.dart' as helpers;

// Mock classes for repositories
class MockInAppNotificationRepository extends Mock
    implements DataRepository<InAppNotification> {}

class MockPushNotificationDeviceRepository extends Mock
    implements DataRepository<PushNotificationDevice> {}

class MockReportRepository extends Mock implements DataRepository<Report> {}

class MockAppReviewRepository extends Mock
    implements DataRepository<AppReview> {}

class MockUserRewardsRepository extends Mock
    implements DataRepository<UserRewards> {}

class MockLanguageRepository extends Mock implements DataRepository<Language> {}

class MockMediaAssetRepository extends Mock
    implements DataRepository<MediaAsset> {}

class MockStorageService extends Mock implements helpers.MockStorageService {}

class MockHeadlineRepository extends Mock implements DataRepository<Headline> {}

class MockContentEnrichmentService extends Mock
    implements ContentEnrichmentService {}

void main() {
  group('DataOperationRegistry', () {
    late DataOperationRegistry registry;
    late User standardUser;

    setUpAll(() {
      helpers.registerSharedFallbackValues();
      registerFallbackValue(helpers.MockRequestContext());
      registerFallbackValue(helpers.createTestUser(id: 'id'));
      registerFallbackValue(
        Engagement(
          id: 'id',
          userId: 'userId',
          entityId: 'entityId',
          entityType: EngageableType.headline,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          reaction: const Reaction(reactionType: ReactionType.like),
        ),
      );
      registerFallbackValue(
        Headline(
          id: 'id',
          title: const {},
          source: Source(
            id: 's',
            name: const {},
            description: const {},
            url: 'u',
            sourceType: SourceType.blog,
            language: SupportedLanguage.en,
            headquarters: const Country(
              id: 'c',
              isoCode: 'US',
              name: {},
              flagUrl: 'f',
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
          eventCountry: const Country(
            id: 'c',
            isoCode: 'US',
            name: {},
            flagUrl: 'f',
          ),
          topic: Topic(
            id: 't',
            name: const {},
            description: const {},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
          isBreaking: false,
          url: 'u',
          imageUrl: 'i',
        ),
      );
      registerFallbackValue(
        const UserContentPreferences(
          id: 'id',
          followedCountries: [],
          followedSources: [],
          followedTopics: [],
          savedHeadlines: [],
          savedHeadlineFilters: [],
        ),
      );
      registerFallbackValue(
        Source(
          id: 'fallback-source',
          name: const {},
          description: const {},
          url: 'fallback-url',
          sourceType: SourceType.blog,
          language: SupportedLanguage.en,
          headquarters: const Country(
            id: 'c',
            isoCode: 'US',
            name: {},
            flagUrl: 'f',
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
        ),
      );
    });

    setUp(() {
      registry = DataOperationRegistry();
      standardUser = helpers.createTestUser(id: 'user-id');
    });

    group('AllItemsReader', () {
      late MockInAppNotificationRepository mockInAppNotificationRepo;
      late MockPushNotificationDeviceRepository mockPushNotificationDeviceRepo;
      late helpers.MockEngagementRepository mockEngagementRepo;
      late MockReportRepository mockReportRepo;
      late MockAppReviewRepository mockAppReviewRepo;
      late MockUserRewardsRepository mockUserRewardsRepo;
      late MockLanguageRepository mockLanguageRepo;

      setUp(() {
        mockInAppNotificationRepo = MockInAppNotificationRepository();
        mockPushNotificationDeviceRepo = MockPushNotificationDeviceRepository();
        mockEngagementRepo = helpers.MockEngagementRepository();
        mockReportRepo = MockReportRepository();
        mockAppReviewRepo = MockAppReviewRepository();
        mockUserRewardsRepo = MockUserRewardsRepository();
        mockLanguageRepo = MockLanguageRepository();

        when(
          () => mockInAppNotificationRepo.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedResponse<InAppNotification>(
            items: [],
            cursor: null,
            hasMore: false,
          ),
        );

        when(
          () => mockPushNotificationDeviceRepo.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedResponse<PushNotificationDevice>(
            items: [],
            cursor: null,
            hasMore: false,
          ),
        );

        when(
          () => mockEngagementRepo.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedResponse<Engagement>(
            items: [],
            cursor: null,
            hasMore: false,
          ),
        );

        when(
          () => mockReportRepo.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedResponse<Report>(
            items: [],
            cursor: null,
            hasMore: false,
          ),
        );

        when(
          () => mockAppReviewRepo.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedResponse<AppReview>(
            items: [],
            cursor: null,
            hasMore: false,
          ),
        );

        when(
          () => mockUserRewardsRepo.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedResponse<UserRewards>(
            items: [],
            cursor: null,
            hasMore: false,
          ),
        );

        when(
          () => mockLanguageRepo.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedResponse<Language>(
            items: [],
            cursor: null,
            hasMore: false,
          ),
        );
      });

      void runUserScopedReaderTests({
        required String modelName,
        required String userIdField,
        required Mock Function() mockRepository,
        required RequestContext Function() contextBuilder,
      }) {
        group('$modelName reader', () {
          test(
            'correctly scopes query by userId when no client filter exists',
            () async {
              final reader = registry.allItemsReaders[modelName]!;
              final context = contextBuilder();

              await reader(context, standardUser.id, null, null, null);

              final captured = verify(
                () => (mockRepository() as DataRepository<dynamic>).readAll(
                  filter: captureAny<Map<String, dynamic>?>(named: 'filter'),
                  userId: null,
                  sort: null,
                  pagination: null,
                ),
              ).captured;

              expect(captured.single, {userIdField: standardUser.id});
            },
          );

          test(
            'merges server-side userId with existing client filter without mutating original',
            () async {
              final reader = registry.allItemsReaders[modelName]!;
              final context = contextBuilder();
              final clientFilter = {'some_field': 'some_value'};
              // Create a copy for comparison to ensure the original is not mutated.
              final originalFilter = Map<String, dynamic>.from(clientFilter);
              await reader(context, standardUser.id, clientFilter, null, null);

              final captured = verify(
                () => (mockRepository() as DataRepository<dynamic>).readAll(
                  filter: captureAny<Map<String, dynamic>?>(named: 'filter'),
                  userId: null,
                  sort: null,
                  pagination: null,
                ),
              ).captured;

              expect(captured.single, {
                'some_field': 'some_value',
                userIdField: standardUser.id,
              });

              // Verify the original filter map was not mutated.
              expect(clientFilter, equals(originalFilter));
            },
          );

          test(
            'overwrites malicious client-provided userId without mutating original filter',
            () async {
              final reader = registry.allItemsReaders[modelName]!;
              final context = contextBuilder();
              final clientFilter = {userIdField: 'another-user-id'};
              // Create a copy for comparison to ensure the original is not mutated.
              final originalFilter = Map<String, dynamic>.from(clientFilter);
              await reader(context, standardUser.id, clientFilter, null, null);

              final captured = verify(
                () => (mockRepository() as DataRepository<dynamic>).readAll(
                  filter: captureAny<Map<String, dynamic>?>(named: 'filter'),
                  userId: null,
                  sort: null,
                  pagination: null,
                ),
              ).captured;

              expect(captured.single, {userIdField: standardUser.id});

              // Verify the original filter map was not mutated.
              expect(clientFilter, equals(originalFilter));
            },
          );
        });
      }

      runUserScopedReaderTests(
        modelName: 'in_app_notification',
        userIdField: 'userId',
        mockRepository: () => mockInAppNotificationRepo,
        contextBuilder: () => helpers
            .createMockRequestContext()
            .provide<DataRepository<InAppNotification>>(
              () => mockInAppNotificationRepo,
            ),
      );

      runUserScopedReaderTests(
        modelName: 'push_notification_device',
        userIdField: 'userId',
        mockRepository: () => mockPushNotificationDeviceRepo,
        contextBuilder: () => helpers
            .createMockRequestContext()
            .provide<DataRepository<PushNotificationDevice>>(
              () => mockPushNotificationDeviceRepo,
            ),
      );

      runUserScopedReaderTests(
        modelName: 'engagement',
        userIdField: 'userId',
        mockRepository: () => mockEngagementRepo,
        contextBuilder: () => helpers
            .createMockRequestContext()
            .provide<DataRepository<Engagement>>(() => mockEngagementRepo),
      );

      runUserScopedReaderTests(
        modelName: 'report',
        userIdField: 'reporterUserId',
        mockRepository: () => mockReportRepo,
        contextBuilder: () => helpers
            .createMockRequestContext()
            .provide<DataRepository<Report>>(() => mockReportRepo),
      );

      runUserScopedReaderTests(
        modelName: 'app_review',
        userIdField: 'userId',
        mockRepository: () => mockAppReviewRepo,
        contextBuilder: () => helpers
            .createMockRequestContext()
            .provide<DataRepository<AppReview>>(() => mockAppReviewRepo),
      );

      runUserScopedReaderTests(
        modelName: 'user_rewards',
        userIdField: 'userId',
        mockRepository: () => mockUserRewardsRepo,
        contextBuilder: () => helpers
            .createMockRequestContext()
            .provide<DataRepository<UserRewards>>(() => mockUserRewardsRepo),
      );
    });

    group('Language Fetcher', () {
      late MockLanguageRepository mockLanguageRepo;
      late Language testLanguage;

      setUp(() {
        mockLanguageRepo = MockLanguageRepository();
        testLanguage = const Language(
          id: 'l1',
          code: 'en',
          name: {
            SupportedLanguage.en: 'English',
            SupportedLanguage.es: 'Inglés',
          },
          nativeName: 'English',
        );
      });

      test('returns raw data for privileged user', () async {
        final fetcher = registry.itemFetchers['language']!;

        when(
          () => mockLanguageRepo.read(id: 'l1', userId: null),
        ).thenAnswer((_) async => testLanguage);

        final context = helpers
            .createMockRequestContext(
              authenticatedUser: helpers.createTestUser(role: UserRole.admin),
            )
            .provide<DataRepository<Language>>(() => mockLanguageRepo);

        final result = await fetcher(context, 'l1');
        expect(result, equals(testLanguage));
        expect((result as Language).name.length, equals(2));
      });

      test('returns localized data for standard user', () async {
        final fetcher = registry.itemFetchers['language']!;

        when(
          () => mockLanguageRepo.read(id: 'l1', userId: null),
        ).thenAnswer((_) async => testLanguage);

        final mockPerms = helpers.MockPermissionService();
        when(() => mockPerms.hasAnyPermission(any(), any())).thenReturn(false);

        final context = helpers
            .createMockRequestContext(
              authenticatedUser: standardUser,
              permissionService: mockPerms,
            )
            .provide<DataRepository<Language>>(() => mockLanguageRepo)
            .provide<SupportedLanguage>(() => SupportedLanguage.es);

        final result = await fetcher(context, 'l1');
        expect(
          (result as Language).name,
          equals({SupportedLanguage.es: 'Inglés'}),
        );
      });
    });

    group('Language Reader', () {
      late MockLanguageRepository mockLanguageRepo;

      setUp(() {
        mockLanguageRepo = MockLanguageRepository();
      });

      test(
        'applies sort rewrite, filter expansion, status removal, and localization',
        () async {
          final reader = registry.allItemsReaders['language']!;
          const testLanguage = Language(
            id: 'l1',
            code: 'en',
            name: {
              SupportedLanguage.en: 'English',
              SupportedLanguage.es: 'Inglés',
            },
            nativeName: 'English',
          );

          when(
            () => mockLanguageRepo.readAll(
              userId: any(named: 'userId'),
              filter: any(named: 'filter'),
              sort: any(named: 'sort'),
              pagination: any(named: 'pagination'),
            ),
          ).thenAnswer(
            (_) async => const PaginatedResponse(
              items: [testLanguage],
              cursor: null,
              hasMore: false,
            ),
          );

          final context = helpers
              .createMockRequestContext()
              .provide<DataRepository<Language>>(() => mockLanguageRepo)
              .provide<SupportedLanguage>(() => SupportedLanguage.es);

          final filter = {'name': 'English', 'status': 'active'};
          final sort = [const SortOption('name', SortOrder.asc)];

          final result = await reader(context, null, filter, sort, null);

          final captured = verify(
            () => mockLanguageRepo.readAll(
              userId: null,
              filter: captureAny(named: 'filter'),
              sort: captureAny(named: 'sort'),
              pagination: null,
            ),
          ).captured;

          final capturedFilter = captured[0] as Map<String, dynamic>;
          final capturedSort = captured[1] as List<SortOption>;

          // Verify sort rewrite
          expect(capturedSort.first.field, equals('name.es'));

          // Verify filter expansion and status removal
          expect(capturedFilter.containsKey('status'), isFalse);
          expect(
            capturedFilter.containsKey(r'$or') ||
                capturedFilter.containsKey(r'$and'),
            isTrue,
          );

          // Verify result localization
          expect(
            result.items.first.name,
            equals({SupportedLanguage.es: 'Inglés'}),
          );
        },
      );
    });

    group('Headline Reader (Localization)', () {
      late MockHeadlineRepository mockHeadlineRepo;

      setUp(() {
        mockHeadlineRepo = MockHeadlineRepository();
        when(
          () => mockHeadlineRepo.readAll(
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedResponse<Headline>(
            items: [],
            cursor: null,
            hasMore: false,
          ),
        );
      });

      test(
        'rewrites sort parameter to localized field (title -> title.es)',
        () async {
          final reader = registry.allItemsReaders['headline']!;

          // Setup context with Spanish language
          final context = helpers
              .createMockRequestContext(
                headers: {'Accept-Language': 'es'},
              )
              .provide<DataRepository<Headline>>(() => mockHeadlineRepo)
              .provide<SupportedLanguage>(() => SupportedLanguage.es);

          final sortOptions = [const SortOption('title', SortOrder.asc)];

          await reader(context, null, null, sortOptions, null);

          final captured = verify(
            () => mockHeadlineRepo.readAll(
              filter: any(named: 'filter'),
              userId: any(named: 'userId'),
              sort: captureAny<List<SortOption>?>(named: 'sort'),
              pagination: any(named: 'pagination'),
            ),
          ).captured;

          final capturedSort = captured.single as List<SortOption>;
          expect(capturedSort.first.field, equals('title.es'));
        },
      );

      test('defaults sort rewrite to .en if language is missing', () async {
        final reader = registry.allItemsReaders['headline']!;

        // Setup context with English (default)
        final context = helpers
            .createMockRequestContext()
            .provide<DataRepository<Headline>>(() => mockHeadlineRepo)
            .provide<SupportedLanguage>(() => SupportedLanguage.en);

        final sortOptions = [const SortOption('title', SortOrder.asc)];

        await reader(context, null, null, sortOptions, null);

        final captured = verify(
          () => mockHeadlineRepo.readAll(
            filter: any(named: 'filter'),
            userId: any(named: 'userId'),
            sort: captureAny<List<SortOption>?>(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).captured;

        final capturedSort = captured.single as List<SortOption>;
        expect(capturedSort.first.field, equals('title.en'));
      });

      test('applies filter expansion to translatable fields', () async {
        final reader = registry.allItemsReaders['headline']!;

        when(
          () => mockHeadlineRepo.readAll(
            userId: any(named: 'userId'),
            filter: any(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedResponse(
            items: [],
            cursor: null,
            hasMore: false,
          ),
        );

        final context = helpers
            .createMockRequestContext()
            .provide<DataRepository<Headline>>(() => mockHeadlineRepo)
            .provide<SupportedLanguage>(() => SupportedLanguage.en);

        final filter = {'title': 'News'};

        await reader(context, null, filter, null, null);

        final captured = verify(
          () => mockHeadlineRepo.readAll(
            userId: null,
            filter: captureAny(named: 'filter'),
            sort: any(named: 'sort'),
            pagination: null,
          ),
        ).captured;

        final capturedFilter = captured.single as Map<String, dynamic>;
        expect(capturedFilter.containsKey(r'$or'), isTrue);
        expect(
          (capturedFilter[r'$or'] as List).any(
            (c) => (c as Map).containsKey('title.en'),
          ),
          isTrue,
        );
      });
    });

    group('Headline Updater (Localization Merging)', () {
      late MockHeadlineRepository mockHeadlineRepo;
      late Headline existingHeadline;
      late MockContentEnrichmentService mockEnrichmentService;

      setUp(() {
        mockHeadlineRepo = MockHeadlineRepository();
        existingHeadline = Headline(
          id: 'h1',
          title: const {SupportedLanguage.en: 'Hello'},
          url: 'url',
          imageUrl: 'img',
          source: Source(
            id: 's',
            name: const {},
            description: const {},
            url: '',
            sourceType: SourceType.other,
            language: SupportedLanguage.en,
            headquarters: const Country(
              id: 'c',
              isoCode: 'US',
              name: {},
              flagUrl: '',
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
          eventCountry: const Country(
            id: 'c',
            isoCode: 'US',
            name: {},
            flagUrl: '',
          ),
          topic: Topic(
            id: 't',
            name: const {},
            description: const {},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
          isBreaking: false,
        );
        mockEnrichmentService = MockContentEnrichmentService();
      });

      test('merges new translation with existing ones', () async {
        final updater = registry.itemUpdaters['headline']!;

        // The update request must be a Headline object (simulating deserialized input).
        // We create a headline with ONLY the Spanish title to verify that the
        // English title from the database is preserved via merging.
        final incomingHeadline = existingHeadline.copyWith(
          title: {SupportedLanguage.es: 'Hola'},
        );

        when(
          () => mockHeadlineRepo.read(
            id: 'h1',
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => existingHeadline);

        when(
          () => mockHeadlineRepo.update(
            id: any(named: 'id'),
            item: any(named: 'item'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (invocation) async => invocation.namedArguments[#item] as Headline,
        );

        final context = helpers
            .createMockRequestContext(
              authenticatedUser: standardUser,
              fetchedItem: FetchedItem(existingHeadline),
            )
            .provide<DataRepository<Headline>>(() => mockHeadlineRepo)
            .provide<ContentEnrichmentService>(() => mockEnrichmentService);

        await updater(context, 'h1', incomingHeadline, null);

        final captured = verify(
          () => mockHeadlineRepo.update(
            id: 'h1',
            item: captureAny<Headline>(named: 'item'),
            userId: any(named: 'userId'),
          ),
        ).captured;

        final updatedItem = captured.single as Headline;
        expect(
          updatedItem.title[SupportedLanguage.en],
          equals('Hello'),
        ); // Preserved
        expect(
          updatedItem.title[SupportedLanguage.es],
          equals('Hola'),
        ); // Added
      });
    });

    group('Engagement Creator', () {
      late helpers.MockEngagementRepository mockEngagementRepository;
      late helpers.MockUserActionLimitService mockUserActionLimitService;

      setUp(() {
        mockEngagementRepository = helpers.MockEngagementRepository();
        mockUserActionLimitService = helpers.MockUserActionLimitService();

        when(
          () => mockEngagementRepository.readAll(
            filter: any(named: 'filter'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedResponse(
            items: [],
            cursor: null,
            hasMore: false,
          ),
        );

        when(
          () => mockUserActionLimitService.checkEngagementCreationLimit(
            user: any(named: 'user'),
            engagement: any(named: 'engagement'),
          ),
        ).thenAnswer((_) async {});
      });

      test(
        'throws ForbiddenException if engagement user ID mismatches',
        () async {
          final creator = registry.itemCreators['engagement']!;
          final engagement = Engagement(
            id: 'id',
            userId: 'different-user-id',
            entityId: 'entityId',
            entityType: EngageableType.headline,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            reaction: const Reaction(reactionType: ReactionType.like),
          );

          final context = helpers.createMockRequestContext(
            authenticatedUser: standardUser,
            userActionLimitService: mockUserActionLimitService,
          );

          expect(
            () => creator(context, engagement, null),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test('throws ConflictException on duplicate engagement', () async {
        final creator = registry.itemCreators['engagement']!;
        final engagement = Engagement(
          id: 'id',
          userId: standardUser.id,
          entityId: 'entityId',
          entityType: EngageableType.headline,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          reaction: const Reaction(reactionType: ReactionType.like),
        );

        when(
          () => mockEngagementRepository.readAll(
            filter: any(named: 'filter'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [engagement],
            cursor: null,
            hasMore: false,
          ),
        );

        final context = helpers.createMockRequestContext(
          authenticatedUser: standardUser,
          engagementRepository: mockEngagementRepository,
          userActionLimitService: mockUserActionLimitService,
        );

        expect(
          () => creator(context, engagement, null),
          throwsA(isA<ConflictException>()),
        );
      });

      test('calls limit service and creates engagement on success', () async {
        final creator = registry.itemCreators['engagement']!;
        final engagement = Engagement(
          id: 'id',
          userId: standardUser.id,
          entityId: 'entityId',
          entityType: EngageableType.headline,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          reaction: const Reaction(reactionType: ReactionType.like),
        );

        when(
          () => mockEngagementRepository.create(item: engagement),
        ).thenAnswer((_) async => engagement);

        final context = helpers.createMockRequestContext(
          authenticatedUser: standardUser,
          engagementRepository: mockEngagementRepository,
          userActionLimitService: mockUserActionLimitService,
        );

        await creator(context, engagement, null);

        verify(
          () => mockUserActionLimitService.checkEngagementCreationLimit(
            user: standardUser,
            engagement: engagement,
          ),
        ).called(1);
        verify(
          () => mockEngagementRepository.create(item: engagement),
        ).called(1);
      });
    });

    group('Engagement Updater', () {
      late helpers.MockEngagementRepository mockEngagementRepository;
      late Engagement existingEngagement;

      setUp(() {
        mockEngagementRepository = helpers.MockEngagementRepository();
        existingEngagement = Engagement(
          id: 'engagement-id',
          userId: standardUser.id,
          entityId: 'entity-id',
          entityType: EngageableType.headline,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          comment: const Comment(
            language: SupportedLanguage.en,
            content: 'Original Content',
            status: ModerationStatus.resolved,
          ),
        );
      });

      test(
        'reverts status to pendingReview when comment content changes',
        () async {
          final updater = registry.itemUpdaters['engagement']!;

          final requestedUpdate = existingEngagement.copyWith(
            comment: ValueWrapper(
              existingEngagement.comment!.copyWith(
                content: 'Updated Content',
                status: ModerationStatus.resolved,
              ),
            ),
          );

          when(
            () => mockEngagementRepository.update(
              id: any(named: 'id'),
              item: any(named: 'item'),
              userId: any(named: 'userId'),
            ),
          ).thenAnswer(
            (invocation) async =>
                invocation.namedArguments[#item] as Engagement,
          );

          final context = helpers.createMockRequestContext(
            authenticatedUser: standardUser,
            engagementRepository: mockEngagementRepository,
            fetchedItem: FetchedItem(existingEngagement),
          );

          final result =
              await updater(
                    context,
                    existingEngagement.id,
                    requestedUpdate,
                    null,
                  )
                  as Engagement;

          expect(result.comment!.content, equals('Updated Content'));
          expect(
            result.comment!.status,
            equals(ModerationStatus.pendingReview),
          );
        },
      );

      test('prevents status change when content is unchanged', () async {
        final updater = registry.itemUpdaters['engagement']!;

        // Start with pendingReview
        final pendingEngagement = existingEngagement.copyWith(
          comment: ValueWrapper(
            existingEngagement.comment!.copyWith(
              status: ModerationStatus.pendingReview,
            ),
          ),
        );

        // Request tries to set to resolved without changing content
        final requestedUpdate = pendingEngagement.copyWith(
          comment: ValueWrapper(
            pendingEngagement.comment!.copyWith(
              status: ModerationStatus.resolved,
            ),
          ),
        );

        when(
          () => mockEngagementRepository.update(
            id: any(named: 'id'),
            item: any(named: 'item'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (invocation) async => invocation.namedArguments[#item] as Engagement,
        );

        final context = helpers.createMockRequestContext(
          authenticatedUser: standardUser,
          engagementRepository: mockEngagementRepository,
          fetchedItem: FetchedItem(pendingEngagement),
        );

        final result =
            await updater(
                  context,
                  pendingEngagement.id,
                  requestedUpdate,
                  null,
                )
                as Engagement;

        expect(result.comment!.content, equals('Original Content'));
        expect(result.comment!.status, equals(ModerationStatus.pendingReview));
      });
    });

    group('User Updater', () {
      late helpers.MockUserRepository mockUserRepository;
      late User userToUpdate;
      late User adminUser;

      setUp(() {
        mockUserRepository = helpers.MockUserRepository();
        userToUpdate = User(
          id: 'user-id',
          email: 'test@example.com',
          role: UserRole.user,
          tier: AccessTier.standard,
          createdAt: DateTime.now(),
        );
        adminUser = User(
          id: 'admin-id',
          email: 'admin@example.com',
          role: UserRole.admin,
          tier: AccessTier.standard,
          createdAt: DateTime.now(),
        );
      });

      test(
        'throws ForbiddenException when regular user attempts to update tier',
        () async {
          final updater = registry.itemUpdaters['user']!;
          final requestBody = userToUpdate
              .copyWith(tier: AccessTier.guest) // Attempt tier change
              .toJson();

          final context = helpers.createMockRequestContext(
            authenticatedUser: standardUser,
            userRepository: mockUserRepository,
            permissionService: const PermissionService(),
            fetchedItem: FetchedItem(userToUpdate),
          );

          expect(
            () => updater(context, userToUpdate.id, requestBody, null),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test(
        'throws ForbiddenException when regular user attempts to update role',
        () async {
          final updater = registry.itemUpdaters['user']!;
          final requestBody = userToUpdate
              .copyWith(role: UserRole.admin) // Attempt admin escalation
              .toJson();

          final context = helpers.createMockRequestContext(
            authenticatedUser: standardUser,
            userRepository: mockUserRepository,
            permissionService: const PermissionService(),
            fetchedItem: FetchedItem(userToUpdate),
          );

          expect(
            () => updater(context, userToUpdate.id, requestBody, null),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test('succeeds when regular user updates their own name', () async {
        final updater = registry.itemUpdaters['user']!;
        final updatedUser = userToUpdate.copyWith(
          name: const ValueWrapper('New Name'),
        );
        final requestBody = updatedUser.toJson();

        when(
          () => mockUserRepository.update(
            id: userToUpdate.id,
            item: updatedUser,
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => updatedUser);

        final context = helpers.createMockRequestContext(
          authenticatedUser: standardUser,
          userRepository: mockUserRepository,
          permissionService: const PermissionService(),
          fetchedItem: FetchedItem(userToUpdate),
        );

        final result = await updater(
          context,
          userToUpdate.id,
          requestBody,
          null,
        );
        expect(result, equals(updatedUser));
      });

      test('succeeds when admin updates user tier', () async {
        final updater = registry.itemUpdaters['user']!;
        final updatedUser = userToUpdate.copyWith(tier: AccessTier.guest);
        final requestBody = updatedUser.toJson();

        when(
          () => mockUserRepository.update(
            id: userToUpdate.id,
            item: updatedUser,
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => updatedUser);

        final context = helpers.createMockRequestContext(
          authenticatedUser: adminUser,
          userRepository: mockUserRepository,
          permissionService: const PermissionService(),
          fetchedItem: FetchedItem(userToUpdate),
        );

        final result = await updater(
          context,
          userToUpdate.id,
          requestBody,
          null,
        );
        expect(result, equals(updatedUser));
      });

      test(
        'throws ForbiddenException when admin attempts to update user name',
        () async {
          final updater = registry.itemUpdaters['user']!;
          final requestBody = userToUpdate
              .copyWith(name: const ValueWrapper('Admin Changed Name'))
              .toJson();

          final context = helpers.createMockRequestContext(
            authenticatedUser: adminUser,
            userRepository: mockUserRepository,
            permissionService: const PermissionService(),
            fetchedItem: FetchedItem(userToUpdate),
          );

          expect(
            () => updater(context, userToUpdate.id, requestBody, null),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );
    });

    group('MediaAsset Deleter', () {
      late MockMediaAssetRepository mockMediaAssetRepository;
      late MockStorageService mockStorageService;

      setUp(() {
        mockMediaAssetRepository = MockMediaAssetRepository();
        mockStorageService = MockStorageService();
      });

      test('deletes from storage first, then deletes from database', () async {
        final deleter = registry.itemDeleters['media_asset']!;
        final asset = MediaAsset(
          id: 'media-asset-id',
          userId: 'user-id',
          purpose: MediaAssetPurpose.headlineImage,
          status: MediaAssetStatus.completed,
          storagePath: 'path/to/file.jpg',
          contentType: 'image/jpeg',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(
          () => mockMediaAssetRepository.read(id: asset.id),
        ).thenAnswer((_) async => asset);
        when(
          () => mockStorageService.deleteObject(
            storagePath: asset.storagePath,
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockMediaAssetRepository.delete(id: asset.id),
        ).thenAnswer((_) async {});

        final context = helpers.createMockRequestContext(
          mediaAssetRepository: mockMediaAssetRepository,
          storageService: mockStorageService,
        );

        await deleter(context, asset.id, null);

        // Use `verifyInOrder` to ensure the sequence of operations is correct.
        verifyInOrder([
          // 1. Fetch the asset to get its path.
          () => mockMediaAssetRepository.read(id: asset.id),
          // 2. Delete the object from cloud storage.
          () => mockStorageService.deleteObject(
            storagePath: asset.storagePath,
          ),
          // 3. Delete the record from the database.
          () => mockMediaAssetRepository.delete(id: asset.id),
        ]);

        verifyNoMoreInteractions(mockStorageService);
        verifyNoMoreInteractions(mockMediaAssetRepository);
      });
    });

    group('Headline Creator', () {
      late MockHeadlineRepository mockHeadlineRepo;
      late MockContentEnrichmentService mockEnrichmentService;
      late Headline testHeadline;

      setUp(() {
        mockHeadlineRepo = MockHeadlineRepository();
        mockEnrichmentService = MockContentEnrichmentService();
        testHeadline = Headline(
          id: 'h1',
          title: const {},
          source: Source(
            id: 's1',
            name: const {},
            description: const {},
            url: '',
            sourceType: SourceType.blog,
            language: SupportedLanguage.en,
            headquarters: const Country(
              id: 'c1',
              isoCode: 'US',
              name: {},
              flagUrl: '',
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
          eventCountry: const Country(
            id: 'c1',
            isoCode: 'US',
            name: {},
            flagUrl: '',
          ),
          topic: Topic(
            id: 't1',
            name: const {},
            description: const {},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
          isBreaking: false,
          url: 'url',
          imageUrl: 'img',
        );

        when(() => mockEnrichmentService.enrichHeadline(any())).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments.first as Headline,
        );

        when(
          () => mockHeadlineRepo.create(
            item: any(named: 'item'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (invocation) async => invocation.namedArguments[#item] as Headline,
        );
      });

      test('calls enrichment service before creation', () async {
        final creator = registry.itemCreators['headline']!;
        final context = helpers
            .createMockRequestContext(authenticatedUser: standardUser)
            .provide<DataRepository<Headline>>(() => mockHeadlineRepo)
            .provide<ContentEnrichmentService>(() => mockEnrichmentService);

        await creator(context, testHeadline, 'uid');

        verify(() => mockEnrichmentService.enrichHeadline(any())).called(1);
        verify(
          () => mockHeadlineRepo.create(
            item: any(named: 'item'),
            userId: 'uid',
          ),
        ).called(1);
      });
    });

    group('Source Creator', () {
      late MockSourceRepository
      mockSourceRepo; // You might need to define this mock class if not exists
      late MockContentEnrichmentService mockEnrichmentService;
      late Source testSource;

      setUp(() {
        mockSourceRepo = MockSourceRepository(); // Assuming you add this class
        mockEnrichmentService = MockContentEnrichmentService();
        testSource = Source(
          id: 's1',
          name: const {},
          description: const {},
          url: '',
          sourceType: SourceType.blog,
          language: SupportedLanguage.en,
          headquarters: const Country(
            id: 'c1',
            isoCode: 'US',
            name: {},
            flagUrl: '',
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
        );

        when(() => mockEnrichmentService.enrichSource(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments.first as Source,
        );

        when(
          () => mockSourceRepo.create(
            item: any(named: 'item'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (invocation) async => invocation.namedArguments[#item] as Source,
        );
      });

      test('calls enrichment service before creation', () async {
        final creator = registry.itemCreators['source']!;
        final context = helpers
            .createMockRequestContext(authenticatedUser: standardUser)
            .provide<DataRepository<Source>>(() => mockSourceRepo)
            .provide<ContentEnrichmentService>(() => mockEnrichmentService);

        await creator(context, testSource, 'uid');

        verify(() => mockEnrichmentService.enrichSource(any())).called(1);
        verify(
          () => mockSourceRepo.create(
            item: any(named: 'item'),
            userId: 'uid',
          ),
        ).called(1);
      });
    });
  });
}

// Helper mock class needed for the Source Creator test
class MockSourceRepository extends Mock implements DataRepository<Source> {}
