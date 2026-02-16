import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/data_operation_registry.dart';
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

class MockMediaAssetRepository extends Mock
    implements DataRepository<MediaAsset> {}

class MockStorageService extends Mock implements helpers.MockStorageService {}

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
        const UserContentPreferences(
          id: 'id',
          followedCountries: [],
          followedSources: [],
          followedTopics: [],
          savedHeadlines: [],
          savedHeadlineFilters: [],
          savedSourceFilters: [],
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

      setUp(() {
        mockInAppNotificationRepo = MockInAppNotificationRepository();
        mockPushNotificationDeviceRepo = MockPushNotificationDeviceRepository();
        mockEngagementRepo = helpers.MockEngagementRepository();
        mockReportRepo = MockReportRepository();
        mockAppReviewRepo = MockAppReviewRepository();
        mockUserRewardsRepo = MockUserRewardsRepository();

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
        final asset = helpers.createTestMediaAsset();

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
  });
}
