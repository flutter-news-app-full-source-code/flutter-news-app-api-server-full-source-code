// c:\Users\workstation\Work\projects\Flutter-News-App-Full-Source-Code-Toolkit\flutter-news-app-api-server-full-source-code\test\src\services\default_user_action_limit_service_test.dart

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/default_user_action_limit_service.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockRemoteConfigRepository extends Mock
    implements DataRepository<RemoteConfig> {}

class MockEngagementRepository extends Mock
    implements DataRepository<Engagement> {}

class MockReportRepository extends Mock implements DataRepository<Report> {}

class MockLogger extends Mock implements Logger {}

void main() {
  group('DefaultUserActionLimitService', () {
    late MockRemoteConfigRepository mockRemoteConfigRepository;
    late MockEngagementRepository mockEngagementRepository;
    late MockReportRepository mockReportRepository;
    late MockLogger mockLogger;
    late DefaultUserActionLimitService service;

    late User standardUser;
    late RemoteConfig mockRemoteConfig;

    setUp(() {
      mockRemoteConfigRepository = MockRemoteConfigRepository();
      mockEngagementRepository = MockEngagementRepository();
      mockReportRepository = MockReportRepository();
      mockLogger = MockLogger();

      service = DefaultUserActionLimitService(
        remoteConfigRepository: mockRemoteConfigRepository,
        engagementRepository: mockEngagementRepository,
        reportRepository: mockReportRepository,
        log: mockLogger,
      );

      standardUser = User(
        id: 'user-123',
        email: 'test@example.com',
        role: UserRole.user,
        tier: AccessTier.standard,
        createdAt: DateTime.now(),
      );

      // Setup a standard RemoteConfig with known limits for testing
      mockRemoteConfig = RemoteConfig(
        id: 'app_config',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        app: const AppConfig(
          maintenance: MaintenanceConfig(isUnderMaintenance: false),
          update: UpdateConfig(
            latestAppVersion: '1.0.0',
            isLatestVersionOnly: false,
            iosUpdateUrl: '',
            androidUpdateUrl: '',
          ),
          general: GeneralAppConfig(
            termsOfServiceUrl: '',
            privacyPolicyUrl: '',
          ),
        ),
        features: const FeaturesConfig(
          analytics: AnalyticsConfig(
            enabled: true,
            activeProvider: AnalyticsProvider.demo,
            disabledEvents: {}, // const implied
            eventSamplingRates: {}, // const implied
          ),
          ads: AdConfig(
            enabled: false,
            primaryAdPlatform: AdPlatformType.demo,
            platformAdIdentifiers: {}, // const implied
            feedAdConfiguration: FeedAdConfiguration(
              enabled: false,
              adType: AdType.native,
              visibleTo: {}, // const implied
            ),
            navigationAdConfiguration: NavigationAdConfiguration(
              enabled: false,
              visibleTo: {}, // const implied
            ),
          ),
          pushNotifications: PushNotificationConfig(
            enabled: false,
            primaryProvider: PushNotificationProvider.firebase,
            deliveryConfigs: {}, // const implied
          ),
          feed: FeedConfig(
            itemClickBehavior: FeedItemClickBehavior.defaultBehavior,
            decorators: {}, // const implied
          ),
          community: CommunityConfig(
            enabled: true,
            engagement: EngagementConfig(
              enabled: true,
              engagementMode: EngagementMode.reactionsAndComments,
            ),
            reporting: ReportingConfig(
              enabled: true,
              headlineReportingEnabled: true,
              sourceReportingEnabled: true,
              commentReportingEnabled: true,
            ),
            appReview: AppReviewConfig(
              enabled: false,
              interactionCycleThreshold: 5,
              initialPromptCooldownDays: 30,
              eligiblePositiveInteractions: [], // const implied
              isNegativeFeedbackFollowUpEnabled: false,
              isPositiveFeedbackFollowUpEnabled: false,
            ),
          ),
          subscription: SubscriptionConfig(
            enabled: false,
            monthlyPlan: PlanDetails(
              enabled: false,
              isRecommended: false,
            ),
            annualPlan: PlanDetails(
              enabled: false,
              isRecommended: true,
            ),
          ),
        ),
        user: const UserConfig(
          limits: UserLimitsConfig(
            followedItems: {AccessTier.standard: 5}, // const implied
            savedHeadlines: {AccessTier.standard: 10}, // const implied
            savedHeadlineFilters: {
              AccessTier.standard: SavedFilterLimits(
                total: 2,
                pinned: 1,
                notificationSubscriptions: {
                  PushNotificationSubscriptionDeliveryType.breakingOnly: 1,
                  PushNotificationSubscriptionDeliveryType.dailyDigest: 1,
                  PushNotificationSubscriptionDeliveryType.weeklyRoundup: 1,
                },
              ),
            },
            savedSourceFilters: {
              AccessTier.standard: SavedFilterLimits(total: 2, pinned: 1),
            },
            commentsPerDay: {AccessTier.standard: 5}, // const implied
            reactionsPerDay: {AccessTier.standard: 10}, // const implied
            reportsPerDay: {AccessTier.standard: 3}, // const implied
          ),
        ),
      );

      when(
        () => mockRemoteConfigRepository.read(id: any(named: 'id')),
      ).thenAnswer((_) async => mockRemoteConfig);
    });

    group('checkUserContentPreferencesLimits', () {
      test('passes when all counts are within limits', () async {
        final preferences = UserContentPreferences(
          id: standardUser.id,
          followedCountries: const [],
          followedSources: const [],
          followedTopics: const [],
          savedHeadlines: const [],
          savedHeadlineFilters: const [],
          savedSourceFilters: const [],
        );

        await expectLater(
          service.checkUserContentPreferencesLimits(
            user: standardUser,
            updatedPreferences: preferences,
          ),
          completes,
        );
      });

      test(
        'throws ForbiddenException when followed items exceed limit',
        () async {
          // Limit is 5
          final preferences = UserContentPreferences(
            id: standardUser.id,
            followedCountries: List.generate(
              6,
              (i) => Country(
                id: '$i',
                isoCode: 'US',
                name: 'US',
                flagUrl: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                status: ContentStatus.active,
              ),
            ),
            followedSources: const [],
            followedTopics: const [],
            savedHeadlines: const [],
            savedHeadlineFilters: const [],
            savedSourceFilters: const [],
          );

          await expectLater(
            service.checkUserContentPreferencesLimits(
              user: standardUser,
              updatedPreferences: preferences,
            ),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test(
        'throws ForbiddenException when followed sources exceed limit',
        () async {
          // Limit is 5
          final preferences = UserContentPreferences(
            id: standardUser.id,
            followedCountries: const [],
            followedSources: List.generate(
              6,
              (i) => Source(
                id: '$i',
                name: 'Source $i',
                description: '',
                url: '',
                logoUrl: '',
                sourceType: SourceType.blog,
                language: Language(
                  id: 'l',
                  code: 'en',
                  name: 'English',
                  nativeName: 'English',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  status: ContentStatus.active,
                ),
                headquarters: Country(
                  id: 'c',
                  isoCode: 'US',
                  name: 'US',
                  flagUrl: '',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  status: ContentStatus.active,
                ),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                status: ContentStatus.active,
              ),
            ),
            followedTopics: const [],
            savedHeadlines: const [],
            savedHeadlineFilters: const [],
            savedSourceFilters: const [],
          );

          await expectLater(
            service.checkUserContentPreferencesLimits(
              user: standardUser,
              updatedPreferences: preferences,
            ),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test(
        'throws ForbiddenException when followed topics exceed limit',
        () async {
          // Limit is 5
          final preferences = UserContentPreferences(
            id: standardUser.id,
            followedCountries: const [],
            followedSources: const [],
            followedTopics: List.generate(
              6,
              (i) => Topic(
                id: '$i',
                name: 'Topic $i',
                description: '',
                iconUrl: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                status: ContentStatus.active,
              ),
            ),
            savedHeadlines: const [],
            savedHeadlineFilters: const [],
            savedSourceFilters: const [],
          );

          await expectLater(
            service.checkUserContentPreferencesLimits(
              user: standardUser,
              updatedPreferences: preferences,
            ),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test(
        'throws ForbiddenException when saved headlines exceed limit',
        () async {
          // Limit is 10
          final preferences = UserContentPreferences(
            id: standardUser.id,
            followedCountries: const [],
            followedSources: const [],
            followedTopics: const [],
            savedHeadlines: List.generate(
              11,
              (i) => Headline(
                id: '$i',
                title: 'Title',
                url: '',
                imageUrl: '',
                source: Source(
                  id: 's',
                  name: 'S',
                  description: '',
                  url: '',
                  logoUrl: '',
                  sourceType: SourceType.blog,
                  language: Language(
                    id: 'l',
                    code: 'en',
                    name: 'English',
                    nativeName: 'English',
                    createdAt: DateTime(2023),
                    updatedAt: DateTime(2023),
                    status: ContentStatus.active,
                  ),
                  headquarters: Country(
                    id: 'c',
                    isoCode: 'US',
                    name: 'US',
                    flagUrl: '',
                    createdAt: DateTime(2023),
                    updatedAt: DateTime(2023),
                    status: ContentStatus.active,
                  ),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  status: ContentStatus.active,
                ),
                eventCountry: Country(
                  id: 'c',
                  isoCode: 'US',
                  name: 'US',
                  flagUrl: '',
                  createdAt: DateTime(2023),
                  updatedAt: DateTime(2023),
                  status: ContentStatus.active,
                ),
                topic: Topic(
                  id: 't',
                  name: 'T',
                  description: '',
                  iconUrl: '',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  status: ContentStatus.active,
                ),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                status: ContentStatus.active,
                isBreaking: false,
              ),
            ),
            savedHeadlineFilters: const [],
            savedSourceFilters: const [],
          );

          await expectLater(
            service.checkUserContentPreferencesLimits(
              user: standardUser,
              updatedPreferences: preferences,
            ),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test(
        'throws ForbiddenException when total saved filters exceed limit',
        () async {
          // Limit is 2
          final preferences = UserContentPreferences(
            id: standardUser.id,
            followedCountries: const [],
            followedSources: const [],
            followedTopics: const [],
            savedHeadlines: const [],
            savedHeadlineFilters: List.generate(
              3,
              (i) => SavedHeadlineFilter(
                id: '$i',
                userId: standardUser.id,
                name: 'Filter $i',
                criteria: const HeadlineFilterCriteria(
                  topics: [],
                  sources: [],
                  countries: [],
                ),
                isPinned: false,
                deliveryTypes: const {},
              ),
            ),
            savedSourceFilters: const [],
          );

          await expectLater(
            service.checkUserContentPreferencesLimits(
              user: standardUser,
              updatedPreferences: preferences,
            ),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test(
        'throws ForbiddenException when pinned filters exceed limit',
        () async {
          // Pinned limit is 1
          final preferences = UserContentPreferences(
            id: standardUser.id,
            followedCountries: const [],
            followedSources: const [],
            followedTopics: const [],
            savedHeadlines: const [],
            savedHeadlineFilters: List.generate(
              2,
              (i) => SavedHeadlineFilter(
                id: '$i',
                userId: standardUser.id,
                name: 'Filter $i',
                criteria: const HeadlineFilterCriteria(
                  topics: [],
                  sources: [],
                  countries: [],
                ),
                isPinned: true, // Both pinned
                deliveryTypes: const {},
              ),
            ),
            savedSourceFilters: const [],
          );

          await expectLater(
            service.checkUserContentPreferencesLimits(
              user: standardUser,
              updatedPreferences: preferences,
            ),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test(
        'throws ForbiddenException when notification subscriptions exceed limit',
        () async {
          // Notification limit for breakingOnly is 1
          final preferences = UserContentPreferences(
            id: standardUser.id,
            followedCountries: const [],
            followedSources: const [],
            followedTopics: const [],
            savedHeadlines: const [],
            savedHeadlineFilters: List.generate(
              2,
              (i) => SavedHeadlineFilter(
                id: '$i',
                userId: standardUser.id,
                name: 'Filter $i',
                criteria: const HeadlineFilterCriteria(
                  topics: [],
                  sources: [],
                  countries: [],
                ),
                isPinned: false,
                deliveryTypes: const {
                  PushNotificationSubscriptionDeliveryType.breakingOnly,
                },
              ),
            ),
            savedSourceFilters: const [],
          );

          await expectLater(
            service.checkUserContentPreferencesLimits(
              user: standardUser,
              updatedPreferences: preferences,
            ),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test(
        'throws ForbiddenException when saved source filters total exceed limit',
        () async {
          // Limit is 2
          final preferences = UserContentPreferences(
            id: standardUser.id,
            followedCountries: const [],
            followedSources: const [],
            followedTopics: const [],
            savedHeadlines: const [],
            savedHeadlineFilters: const [],
            savedSourceFilters: List.generate(
              3,
              (i) => SavedSourceFilter(
                id: '$i',
                userId: standardUser.id,
                name: 'Source Filter $i',
                criteria: const SourceFilterCriteria(
                  sourceTypes: [],
                  languages: [],
                  countries: [],
                ),
                isPinned: false,
              ),
            ),
          );

          await expectLater(
            service.checkUserContentPreferencesLimits(
              user: standardUser,
              updatedPreferences: preferences,
            ),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test(
        'throws ForbiddenException when saved source filters pinned exceed limit',
        () async {
          // Pinned limit is 1
          final preferences = UserContentPreferences(
            id: standardUser.id,
            followedCountries: const [],
            followedSources: const [],
            followedTopics: const [],
            savedHeadlines: const [],
            savedHeadlineFilters: const [],
            savedSourceFilters: List.generate(
              2,
              (i) => SavedSourceFilter(
                id: '$i',
                userId: standardUser.id,
                name: 'Source Filter $i',
                criteria: const SourceFilterCriteria(
                  sourceTypes: [],
                  languages: [],
                  countries: [],
                ),
                isPinned: true,
              ),
            ),
          );

          await expectLater(
            service.checkUserContentPreferencesLimits(
              user: standardUser,
              updatedPreferences: preferences,
            ),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test(
        'throws ForbiddenException when notification limit configuration is missing',
        () async {
          // Setup a malformed config where dailyDigest is missing
          final malformedConfig = mockRemoteConfig.copyWith(
            user: UserConfig(
              limits: mockRemoteConfig.user.limits.copyWith(
                savedHeadlineFilters: {
                  AccessTier.standard: const SavedFilterLimits(
                    total: 2,
                    pinned: 1,
                    notificationSubscriptions: {
                      PushNotificationSubscriptionDeliveryType.breakingOnly: 1,
                      // Missing dailyDigest and weeklyRoundup
                    },
                  ),
                },
              ),
            ),
          );

          when(
            () => mockRemoteConfigRepository.read(id: any(named: 'id')),
          ).thenAnswer((_) async => malformedConfig);

          // Even with empty preferences, the service checks config validity
          final preferences = UserContentPreferences(
            id: standardUser.id,
            followedCountries: const [],
            followedSources: const [],
            followedTopics: const [],
            savedHeadlines: const [],
            savedHeadlineFilters: const [],
            savedSourceFilters: const [],
          );

          await expectLater(
            service.checkUserContentPreferencesLimits(
              user: standardUser,
              updatedPreferences: preferences,
            ),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );
    });

    group('checkEngagementCreationLimit', () {
      test('passes when reaction count is below limit', () async {
        // Limit is 10
        when(
          () => mockEngagementRepository.count(filter: any(named: 'filter')),
        ).thenAnswer((_) async => 5);

        final engagement = Engagement(
          id: 'e1',
          userId: standardUser.id,
          entityId: 'h1',
          entityType: EngageableType.headline,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          reaction: const Reaction(reactionType: ReactionType.like),
        );

        await expectLater(
          service.checkEngagementCreationLimit(
            user: standardUser,
            engagement: engagement,
          ),
          completes,
        );
      });

      test(
        'throws ForbiddenException when reaction count exceeds limit',
        () async {
          // Limit is 10
          when(
            () => mockEngagementRepository.count(filter: any(named: 'filter')),
          ).thenAnswer((_) async => 10);

          final engagement = Engagement(
            id: 'e1',
            userId: standardUser.id,
            entityId: 'h1',
            entityType: EngageableType.headline,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            reaction: const Reaction(reactionType: ReactionType.like),
          );

          await expectLater(
            service.checkEngagementCreationLimit(
              user: standardUser,
              engagement: engagement,
            ),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );

      test('passes when comment count is below limit', () async {
        // Limit is 5
        when(
          () => mockEngagementRepository.count(filter: any(named: 'filter')),
        ).thenAnswer((_) async => 2);

        final engagement = Engagement(
          id: 'e1',
          userId: standardUser.id,
          entityId: 'h1',
          entityType: EngageableType.headline,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          comment: Comment(
            language: Language(
              id: 'l',
              code: 'en',
              name: 'English',
              nativeName: 'English',
              createdAt: DateTime(2023),
              updatedAt: DateTime(2023),
              status: ContentStatus.active,
            ),
            content: 'Test comment',
          ),
        );

        await expectLater(
          service.checkEngagementCreationLimit(
            user: standardUser,
            engagement: engagement,
          ),
          completes,
        );
      });

      test(
        'throws ForbiddenException when comment count exceeds limit',
        () async {
          // Limit is 5
          when(
            () => mockEngagementRepository.count(filter: any(named: 'filter')),
          ).thenAnswer((_) async => 5);

          final engagement = Engagement(
            id: 'e1',
            userId: standardUser.id,
            entityId: 'h1',
            entityType: EngageableType.headline,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            comment: Comment(
              language: Language(
                id: 'l',
                code: 'en',
                name: 'English',
                nativeName: 'English',
                createdAt: DateTime(2023),
                updatedAt: DateTime(2023),
                status: ContentStatus.active,
              ),
              content: 'Test comment',
            ),
          );

          await expectLater(
            service.checkEngagementCreationLimit(
              user: standardUser,
              engagement: engagement,
            ),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );
    });

    group('checkReportCreationLimit', () {
      test('passes when report count is below limit', () async {
        // Limit is 3
        when(
          () => mockReportRepository.count(filter: any(named: 'filter')),
        ).thenAnswer((_) async => 1);

        await expectLater(
          service.checkReportCreationLimit(user: standardUser),
          completes,
        );
      });

      test(
        'throws ForbiddenException when report count exceeds limit',
        () async {
          // Limit is 3
          when(
            () => mockReportRepository.count(filter: any(named: 'filter')),
          ).thenAnswer((_) async => 3);

          await expectLater(
            service.checkReportCreationLimit(user: standardUser),
            throwsA(isA<ForbiddenException>()),
          );
        },
      );
    });
  });
}
