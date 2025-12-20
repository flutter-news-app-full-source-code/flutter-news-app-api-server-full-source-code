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

      setUp(() {
        mockUserRepository = MockUserRepository();
        userToUpdate = createTestUser(id: 'user-id');
      });

      test(
        'throws ForbiddenException when regular user updates roles',
        () async {
          final updater = registry.itemUpdaters['user']!;
          final requestBody = userToUpdate
              .copyWith(appRole: AppUserRole.premiumUser)
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
    });
  });
}
