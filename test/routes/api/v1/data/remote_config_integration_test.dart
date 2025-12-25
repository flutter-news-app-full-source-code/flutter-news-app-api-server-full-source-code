import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../src/helpers/test_helpers.dart';
import 'test_api.dart';

void main() {
  group('RemoteConfig Integration Tests', () {
    late TestApi api;
    late MockDataRepository<RemoteConfig> mockRepo;
    late MockPermissionService mockPermissionService;
    late MockAuthTokenService mockAuthTokenService;

    late User adminUser;
    late String adminToken;

    late RemoteConfig remoteConfig;

    setUpAll(() {
      registerSharedFallbackValues();
      registerFallbackValue(
        RemoteConfig(
          id: 'fallback-id',
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
            ads: AdConfig(
              enabled: false,
              primaryAdPlatform: AdPlatformType.demo,
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
            analytics: AnalyticsConfig(
              enabled: false,
              activeProvider: AnalyticsProvider.demo,
              disabledEvents: {},
              eventSamplingRates: {},
            ),
            pushNotifications: PushNotificationConfig(
              enabled: false,
              primaryProvider: PushNotificationProvider.firebase,
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
            subscription: SubscriptionConfig(
              enabled: false,
              enabledProviders: [],
              monthlyPlan: PlanDetails(
                enabled: true,
                isRecommended: false,
                appleProductId: 'monthly_ios',
              ),
              annualPlan: PlanDetails(
                enabled: true,
                isRecommended: true,
                appleProductId: 'annual_ios',
              ),
            ),
          ),
          user: const UserConfig(
            limits: UserLimitsConfig(
              followedItems: {},
              savedHeadlines: {},
              savedHeadlineFilters: {},
              savedSourceFilters: {},
              commentsPerDay: {},
              reactionsPerDay: {},
              reportsPerDay: {},
            ),
          ),
        ),
      );
    });

    setUp(() {
      mockRepo = MockDataRepository<RemoteConfig>();
      mockAuthTokenService = MockAuthTokenService();
      mockPermissionService = MockPermissionService();

      adminUser = createTestUser(
        id: 'admin-id',
        email: 'admin@test.com',
        role: UserRole.admin,
      );

      adminToken = 'admin-token';

      when(
        () => mockAuthTokenService.validateToken(adminToken),
      ).thenAnswer((_) async => adminUser);

      remoteConfig = RemoteConfig(
        id: 'config-1',
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
          ads: AdConfig(
            enabled: false,
            primaryAdPlatform: AdPlatformType.demo,
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
          analytics: AnalyticsConfig(
            enabled: false,
            activeProvider: AnalyticsProvider.demo,
            disabledEvents: {},
            eventSamplingRates: {},
          ),
          pushNotifications: PushNotificationConfig(
            enabled: false,
            primaryProvider: PushNotificationProvider.firebase,
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
          subscription: SubscriptionConfig(
            enabled: false,
            enabledProviders: [],
            monthlyPlan: PlanDetails(
              enabled: true,
              isRecommended: false,
              appleProductId: 'monthly_ios',
            ),
            annualPlan: PlanDetails(
              enabled: true,
              isRecommended: true,
              appleProductId: 'annual_ios',
            ),
          ),
        ),
        user: const UserConfig(
          limits: UserLimitsConfig(
            followedItems: {},
            savedHeadlines: {},
            savedHeadlineFilters: {},
            savedSourceFilters: {},
            commentsPerDay: {},
            reactionsPerDay: {},
            reportsPerDay: {},
          ),
        ),
      );

      api = TestApi.from(
        (context) => context
            .provide<DataRepository<RemoteConfig>>(() => mockRepo)
            .provide<AuthTokenService>(() => mockAuthTokenService)
            // Provide the missing PermissionService for the rate limiter check
            .provide<PermissionService>(() => mockPermissionService),
      );
    });

    group('GET /api/v1/data/:id?model=remote_config', () {
      test('returns 200 for unauthenticated user (public access)', () async {
        when(
          () => mockRepo.read(id: 'config-1'),
        ).thenAnswer((_) async => remoteConfig);

        final response = await api.get(
          '/api/v1/data/config-1?model=remote_config',
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(await response.body());
        expect(body['data']['id'], 'config-1');
      });
    });

    group('PUT /api/v1/data/:id?model=remote_config', () {
      setUp(() {
        when(
          () => mockRepo.read(id: remoteConfig.id),
        ).thenAnswer((_) async => remoteConfig);
      });

      test('returns 200 for admin user', () async {
        final updatedConfig = remoteConfig.copyWith(
          app: remoteConfig.app.copyWith(
            maintenance: const MaintenanceConfig(isUnderMaintenance: true),
          ),
        );

        when(
          () => mockRepo.update(
            id: remoteConfig.id,
            item: any(named: 'item'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => updatedConfig);

        final response = await api.put(
          '/api/v1/data/${remoteConfig.id}?model=remote_config',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(updatedConfig.toJson()),
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(await response.body());
        expect(body['data']['app']['maintenance']['isUnderMaintenance'], true);
      });

      test('returns 401 for unauthenticated user', () async {
        final response = await api.put(
          '/api/v1/data/${remoteConfig.id}?model=remote_config',
          body: jsonEncode(remoteConfig.toJson()),
        );

        expect(response.statusCode, 401);
      });
    });
  });
}
