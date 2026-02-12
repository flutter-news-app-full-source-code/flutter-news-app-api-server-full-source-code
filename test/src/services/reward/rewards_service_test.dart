import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/reward/admob_reward_callback.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/idempotency_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/reward/admob_ssv_verifier.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/reward/rewards_service.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockDataRepository<T> extends Mock implements DataRepository<T> {}

class MockIdempotencyService extends Mock implements IdempotencyService {}

class MockAdMobSsvVerifier extends Mock implements AdMobSsvVerifier {}

void main() {
  group('RewardsService', () {
    late RewardsService service;
    late MockDataRepository<UserRewards> mockUserRewardsRepo;
    late MockDataRepository<RemoteConfig> mockRemoteConfigRepo;
    late MockIdempotencyService mockIdempotencyService;
    late MockAdMobSsvVerifier mockVerifier;

    final uri = Uri.parse(
      'https://e.com?transaction_id=tx1&user_id=user1&custom_data=adFree&reward_amount=10&signature=sig&key_id=k',
    );

    final remoteConfig = RemoteConfig(
      id: 'config',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      app: const AppConfig(
        maintenance: MaintenanceConfig(isUnderMaintenance: false),
        update: UpdateConfig(
          latestAppVersion: '1.0',
          isLatestVersionOnly: false,
          iosUpdateUrl: '',
          androidUpdateUrl: '',
        ),
        general: GeneralAppConfig(
          termsOfServiceUrl: '',
          privacyPolicyUrl: '',
        ),
        initialPersonalization: InitialPersonalizationConfig(
          isEnabled: true,
          isCountrySelectionEnabled: true,
          isTopicSelectionEnabled: true,
          isSourceSelectionEnabled: true,
          minSelectionsRequired: 3,
        ),
      ),
      features: const FeaturesConfig(
        analytics: AnalyticsConfig(
          enabled: false,
          activeProvider: AnalyticsProviders.mixpanel,
          disabledEvents: {},
          eventSamplingRates: {},
        ),
        ads: AdConfig(
          enabled: false,
          primaryAdPlatform: AdPlatformType.admob,
          platformAdIdentifiers: {},
          feedAdConfiguration: FeedAdConfiguration(
            enabled: false,
            adType: AdType.banner,
            visibleTo: {},
          ),
          navigationAdConfiguration: NavigationAdConfiguration(
            enabled: false,
            visibleTo: {},
          ),
        ),
        pushNotifications: PushNotificationConfig(
          enabled: false,
          primaryProvider: PushNotificationProviders.firebase,
          deliveryConfigs: {},
        ),
        feed: FeedConfig(
          itemClickBehavior: FeedItemClickBehavior.defaultBehavior,
          decorators: {},
        ),
        community: CommunityConfig(
          enabled: false,
          engagement: EngagementConfig(
            enabled: false,
            engagementMode: EngagementMode.reactionsOnly,
          ),
          reporting: ReportingConfig(
            enabled: false,
            headlineReportingEnabled: false,
            sourceReportingEnabled: false,
            commentReportingEnabled: false,
          ),
          appReview: AppReviewConfig(
            enabled: false,
            interactionCycleThreshold: 0,
            initialPromptCooldownDays: 0,
            eligiblePositiveInteractions: [],
            isNegativeFeedbackFollowUpEnabled: false,
            isPositiveFeedbackFollowUpEnabled: false,
          ),
        ),
        rewards: RewardsConfig(
          enabled: true,
          rewards: {
            RewardType.adFree: RewardDetails(enabled: true, durationDays: 1),
          },
        ),
      ),
      user: const UserConfig(
        limits: UserLimitsConfig(
          followedItems: {},
          savedHeadlines: {},
          savedHeadlineFilters: {},
          savedSourceFilters: {},
          reactionsPerDay: {},
          commentsPerDay: {},
          reportsPerDay: {},
        ),
      ),
    );

    setUp(() {
      mockUserRewardsRepo = MockDataRepository<UserRewards>();
      mockRemoteConfigRepo = MockDataRepository<RemoteConfig>();
      mockIdempotencyService = MockIdempotencyService();
      mockVerifier = MockAdMobSsvVerifier();

      service = RewardsService(
        userRewardsRepository: mockUserRewardsRepo,
        remoteConfigRepository: mockRemoteConfigRepo,
        idempotencyService: mockIdempotencyService,
        admobVerifier: mockVerifier,
        log: Logger('TestRewardsService'),
      );

      registerFallbackValue(
        AdMobRewardCallback(
          transactionId: '',
          userId: '',
          rewardItem: '',
          rewardAmount: 0,
          signature: '',
          keyId: '',
          originalUri: Uri(),
        ),
      );
      registerFallbackValue(
        const UserRewards(id: '', userId: '', activeRewards: {}),
      );

      // Default mocks
      when(
        () => mockVerifier.verify(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockIdempotencyService.isEventProcessed(any()),
      ).thenAnswer((_) async => false);
      when(
        () => mockIdempotencyService.recordEvent(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockRemoteConfigRepo.read(id: any(named: 'id')),
      ).thenAnswer((_) async => remoteConfig);

      // Stub read to return NotFound by default so flow continues to create
      when(
        () => mockUserRewardsRepo.read(id: any(named: 'id')),
      ).thenThrow(const NotFoundException(''));

      // Stub create to return a dummy
      when(
        () => mockUserRewardsRepo.create(item: any(named: 'item')),
      ).thenAnswer(
        (_) async => const UserRewards(
          id: 'user1',
          userId: 'user1',
          activeRewards: {},
        ),
      );

      // Stub update
      when(
        () => mockUserRewardsRepo.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      ).thenAnswer(
        (_) async => const UserRewards(
          id: 'user1',
          userId: 'user1',
          activeRewards: {},
        ),
      );
    });

    test('processAdMobCallback verifies signature first', () async {
      await service.processAdMobCallback(uri);
      verify(() => mockVerifier.verify(any())).called(1);
    });

    test('processAdMobCallback skips if event already processed', () async {
      when(
        () => mockIdempotencyService.isEventProcessed('tx1'),
      ).thenAnswer((_) async => true);

      await service.processAdMobCallback(uri);

      verifyNever(
        () => mockUserRewardsRepo.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      );
    });

    test(
      'processAdMobCallback throws BadRequest for unknown reward type',
      () async {
        final badUri = Uri.parse(
          'https://e.com?transaction_id=tx1&user_id=user1&custom_data=UNKNOWN&signature=s&key_id=k',
        );
        expect(
          () => service.processAdMobCallback(badUri),
          throwsA(isA<BadRequestException>()),
        );
      },
    );

    test(
      'processAdMobCallback handles case-insensitive reward types (e.g. DailyDigest)',
      () async {
        // Setup: URI with PascalCase 'DailyDigest'
        final mixedCaseUri = Uri.parse(
          'https://e.com?transaction_id=tx_mixed&user_id=user1&custom_data=DailyDigest&reward_amount=1&signature=s&key_id=k',
        );

        // Ensure config has dailyDigest enabled
        final digestConfig = remoteConfig.copyWith(
          features: remoteConfig.features.copyWith(
            rewards: const RewardsConfig(
              enabled: true,
              rewards: {
                RewardType.dailyDigest: RewardDetails(
                  enabled: true,
                  durationDays: 1,
                ),
              },
            ),
          ),
        );

        when(
          () => mockRemoteConfigRepo.read(id: any(named: 'id')),
        ).thenAnswer((_) async => digestConfig);

        await service.processAdMobCallback(mixedCaseUri);

        final captured =
            verify(
                  () => mockUserRewardsRepo.create(
                    item: captureAny(named: 'item'),
                  ),
                ).captured.first
                as UserRewards;

        expect(
          captured.activeRewards.containsKey(RewardType.dailyDigest),
          isTrue,
        );
      },
    );

    test('processAdMobCallback throws Forbidden if reward disabled', () async {
      final disabledConfig = remoteConfig.copyWith(
        features: remoteConfig.features.copyWith(
          rewards: const RewardsConfig(
            enabled: true,
            rewards: {
              RewardType.adFree: RewardDetails(enabled: false, durationDays: 1),
            },
          ),
        ),
      );
      when(
        () => mockRemoteConfigRepo.read(id: any(named: 'id')),
      ).thenAnswer((_) async => disabledConfig);

      expect(
        () => service.processAdMobCallback(uri),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test(
      'processAdMobCallback grants reward using RemoteConfig duration (ignoring AdMob amount)',
      () async {
        // Setup: User has no existing rewards (default stub handles this)

        await service.processAdMobCallback(uri);

        final captured =
            verify(
                  () => mockUserRewardsRepo.create(
                    item: captureAny(named: 'item'),
                  ),
                ).captured.first
                as UserRewards;

        expect(captured.userId, 'user1');
        expect(captured.activeRewards.containsKey(RewardType.adFree), isTrue);

        // Verify duration is approx 1 day (from config) not 10 days (from uri)
        final expiry = captured.activeRewards[RewardType.adFree]!;
        final difference = expiry.difference(DateTime.now()).inHours;
        expect(difference, closeTo(24, 1)); // 24 hours +/- 1 hour

        verifyNever(
          () => mockUserRewardsRepo.update(
            id: any(named: 'id'),
            item: any(named: 'item'),
          ),
        );
      },
    );

    test('processAdMobCallback extends existing reward', () async {
      // Setup: User has active reward expiring in 5 hours
      final existingExpiry = DateTime.now().add(const Duration(hours: 5));
      final existingRewards = UserRewards(
        id: 'user1',
        userId: 'user1',
        activeRewards: {RewardType.adFree: existingExpiry},
      );

      when(
        () => mockUserRewardsRepo.read(id: 'user1'),
      ).thenAnswer((_) async => existingRewards);
      when(
        () => mockUserRewardsRepo.update(
          id: 'user1',
          item: any(named: 'item'),
        ),
      ).thenAnswer((_) async => existingRewards);

      await service.processAdMobCallback(uri);

      final captured =
          verify(
                () => mockUserRewardsRepo.update(
                  id: 'user1',
                  item: captureAny(named: 'item'),
                ),
              ).captured.first
              as UserRewards;

      final newExpiry = captured.activeRewards[RewardType.adFree]!;
      // Should be existing (5h) + new (24h) = 29h
      final difference = newExpiry.difference(DateTime.now()).inHours;
      expect(difference, closeTo(29, 1));
    });

    test('processAdMobCallback records idempotency after success', () async {
      await service.processAdMobCallback(uri);

      verify(() => mockIdempotencyService.recordEvent('tx1')).called(1);
    });
  });
}
