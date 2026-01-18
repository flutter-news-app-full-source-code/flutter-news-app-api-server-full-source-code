import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/data_operation_registry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('DataOperationRegistry', () {
    late DataOperationRegistry registry;
    late User standardUser;

    setUpAll(() {
      registerSharedFallbackValues();
      registerFallbackValue(MockRequestContext());
      registerFallbackValue(createTestUser(id: 'id'));
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
      standardUser = createTestUser(id: 'user-id');
    });

    group('Engagement Creator', () {
      late MockEngagementRepository mockEngagementRepository;
      late MockUserActionLimitService mockUserActionLimitService;

      setUp(() {
        mockEngagementRepository = MockEngagementRepository();
        mockUserActionLimitService = MockUserActionLimitService();

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

          final context = createMockRequestContext(
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

        final context = createMockRequestContext(
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

        final context = createMockRequestContext(
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
      late MockUserRepository mockUserRepository;
      late User userToUpdate;
      late User adminUser;

      setUp(() {
        mockUserRepository = MockUserRepository();
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

          final context = createMockRequestContext(
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

          final context = createMockRequestContext(
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
        final updatedUser = userToUpdate.copyWith(name: 'New Name');
        final requestBody = updatedUser.toJson();

        when(
          () => mockUserRepository.update(
            id: userToUpdate.id,
            item: updatedUser,
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => updatedUser);

        final context = createMockRequestContext(
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

        final context = createMockRequestContext(
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
              .copyWith(name: 'Admin Changed Name')
              .toJson();

          final context = createMockRequestContext(
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
  });
}
