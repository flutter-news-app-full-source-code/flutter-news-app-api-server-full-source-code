import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../src/helpers/test_helpers.dart';
import 'test_api.dart';

void main() {
  group('AppSettings Integration Tests', () {
    late TestApi api;
    late MockDataRepository<AppSettings> mockAppSettingsRepository;
    late MockAuthTokenService mockAuthTokenService;

    late User adminUser;
    late User standardUser;
    late User otherUser;
    late String adminToken;
    late String standardToken;
    late String otherUserToken;

    late AppSettings standardUserSettings;
    late AppSettings otherUserSettings;

    setUp(() {
      mockAppSettingsRepository = MockDataRepository<AppSettings>();
      mockAuthTokenService = MockAuthTokenService();

      adminUser = User(
        id: 'admin-id',
        email: 'admin@test.com',
        dashboardRole: DashboardUserRole.admin,
        appRole: AppUserRole.standardUser,
        createdAt: DateTime.now(),
        feedDecoratorStatus: const {},
      );
      standardUser = User(
        id: 'standard-id',
        email: 'standard@test.com',
        appRole: AppUserRole.standardUser,
        dashboardRole: DashboardUserRole.none,
        createdAt: DateTime.now(),
        feedDecoratorStatus: const {},
      );
      otherUser = User(
        id: 'other-id',
        email: 'other@test.com',
        appRole: AppUserRole.standardUser,
        dashboardRole: DashboardUserRole.none,
        createdAt: DateTime.now(),
        feedDecoratorStatus: const {},
      );

      adminToken = 'admin-token';
      standardToken = 'standard-token';
      otherUserToken = 'other-user-token';

      when(
        () => mockAuthTokenService.validateToken(adminToken),
      ).thenAnswer((_) async => adminUser);
      when(
        () => mockAuthTokenService.validateToken(standardToken),
      ).thenAnswer((_) async => standardUser);
      when(
        () => mockAuthTokenService.validateToken(otherUserToken),
      ).thenAnswer((_) async => otherUser);

      standardUserSettings = AppSettings(
        id: standardUser.id,
        language: Language(
          id: 'en',
          code: 'en',
          name: 'English',
          nativeName: 'English',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
        ),
        displaySettings: const DisplaySettings(
          baseTheme: AppBaseTheme.system,
          accentTheme: AppAccentTheme.defaultBlue,
          fontFamily: 'SystemDefault',
          textScaleFactor: AppTextScaleFactor.medium,
          fontWeight: AppFontWeight.regular,
        ),
        feedSettings: const FeedSettings(
          feedItemDensity: FeedItemDensity.standard,
          feedItemImageStyle: FeedItemImageStyle.smallThumbnail,
          feedItemClickBehavior: FeedItemClickBehavior.defaultBehavior,
        ),
      );
      otherUserSettings = AppSettings(
        id: otherUser.id,
        language: Language(
          id: 'es',
          code: 'es',
          name: 'Spanish',
          nativeName: 'Español',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
        ),
        displaySettings: const DisplaySettings(
          baseTheme: AppBaseTheme.system,
          accentTheme: AppAccentTheme.defaultBlue,
          fontFamily: 'SystemDefault',
          textScaleFactor: AppTextScaleFactor.medium,
          fontWeight: AppFontWeight.regular,
        ),
        feedSettings: const FeedSettings(
          feedItemDensity: FeedItemDensity.standard,
          feedItemImageStyle: FeedItemImageStyle.smallThumbnail,
          feedItemClickBehavior: FeedItemClickBehavior.defaultBehavior,
        ),
      );

      api = TestApi.from(
        (context) => context
            .provide<DataRepository<AppSettings>>(
              () => mockAppSettingsRepository,
            )
            .provide<AuthTokenService>(() => mockAuthTokenService),
      );
    });

    group('GET /api/v1/data/:id?model=app_settings (Item)', () {
      test('returns 200 for admin user getting any user settings', () async {
        when(
          () => mockAppSettingsRepository.read(id: standardUser.id),
        ).thenAnswer((_) async => standardUserSettings);

        final response = await api.get(
          '/api/v1/data/${standardUser.id}?model=app_settings',
          headers: {'Authorization': 'Bearer $adminToken'},
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(await response.body());
        expect(body['data']['id'], standardUser.id);
      });

      test(
        'returns 200 for standard user getting their own settings',
        () async {
          when(
            () => mockAppSettingsRepository.read(id: standardUser.id),
          ).thenAnswer((_) async => standardUserSettings);

          final response = await api.get(
            '/api/v1/data/${standardUser.id}?model=app_settings',
            headers: {'Authorization': 'Bearer $standardToken'},
          );

          expect(response.statusCode, 200);
          final body = jsonDecode(await response.body());
          expect(body['data']['id'], standardUser.id);
        },
      );

      test(
        'returns 403 for standard user getting another user settings',
        () async {
          when(
            () => mockAppSettingsRepository.read(id: otherUser.id),
          ).thenAnswer((_) async => otherUserSettings);

          final response = await api.get(
            '/api/v1/data/${otherUser.id}?model=app_settings',
            headers: {'Authorization': 'Bearer $standardToken'},
          );

          expect(response.statusCode, 403);
        },
      );

      test('returns 401 for unauthenticated user', () async {
        final response = await api.get(
          '/api/v1/data/${standardUser.id}?model=app_settings',
        );
        expect(response.statusCode, 401);
      });
    });

    group('PUT /api/v1/data/:id?model=app_settings (Item)', () {
      setUp(() {
        // Pre-fetch middleware needs to find the item
        when(
          () => mockAppSettingsRepository.read(id: standardUser.id),
        ).thenAnswer((_) async => standardUserSettings);
        when(
          () => mockAppSettingsRepository.read(id: otherUser.id),
        ).thenAnswer((_) async => otherUserSettings);
      });

      test('returns 200 for admin user updating any user settings', () async {
        final updatedSettings = standardUserSettings.copyWith(
          language: Language(
            id: 'fr',
            code: 'fr',
            name: 'French',
            nativeName: 'Français',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
        );

        when(
          () => mockAppSettingsRepository.update(
            id: standardUser.id,
            item: any(named: 'item'),
          ),
        ).thenAnswer((_) async => updatedSettings);

        final response = await api.put(
          '/api/v1/data/${standardUser.id}?model=app_settings',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(updatedSettings.toJson()),
        );

        expect(response.statusCode, 200);
        final body = jsonDecode(await response.body());
        expect(body['data']['language']['id'], 'fr');
      });

      test(
        'returns 200 for standard user updating their own settings',
        () async {
          final updatedSettings = standardUserSettings.copyWith(
            language: Language(
              id: 'de',
              code: 'de',
              name: 'German',
              nativeName: 'Deutsch',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              status: ContentStatus.active,
            ),
          );

          when(
            () => mockAppSettingsRepository.update(
              id: standardUser.id,
              item: any(named: 'item'),
            ),
          ).thenAnswer((_) async => updatedSettings);

          final response = await api.put(
            '/api/v1/data/${standardUser.id}?model=app_settings',
            headers: {'Authorization': 'Bearer $standardToken'},
            body: jsonEncode(updatedSettings.toJson()),
          );

          expect(response.statusCode, 200);
          final body = jsonDecode(await response.body());
          expect(body['data']['language']['id'], 'de');
        },
      );

      test(
        'returns 403 for standard user updating another user settings',
        () async {
          final updatedSettings = otherUserSettings.copyWith(
            language: Language(
              id: 'de',
              code: 'de',
              name: 'German',
              nativeName: 'Deutsch',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              status: ContentStatus.active,
            ),
          );

          final response = await api.put(
            '/api/v1/data/${otherUser.id}?model=app_settings',
            headers: {'Authorization': 'Bearer $standardToken'},
            body: jsonEncode(updatedSettings.toJson()),
          );

          expect(response.statusCode, 403);
        },
      );

      test('returns 401 for unauthenticated user', () async {
        final updatedSettings = standardUserSettings.copyWith(
          language: Language(
            id: 'de',
            code: 'de',
            name: 'German',
            nativeName: 'Deutsch',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
        );

        final response = await api.put(
          '/api/v1/data/${standardUser.id}?model=app_settings',
          body: jsonEncode(updatedSettings.toJson()),
        );

        expect(response.statusCode, 401);
      });
    });

    group('POST and DELETE', () {
      test('returns 403 for POST (unsupported)', () async {
        final response = await api.post(
          '/api/v1/data?model=app_settings',
          headers: {'Authorization': 'Bearer $adminToken'},
          body: jsonEncode(standardUserSettings.toJson()),
        );
        expect(response.statusCode, 403);
      });

      test('returns 403 for DELETE (unsupported)', () async {
        final response = await api.delete(
          '/api/v1/data/${standardUser.id}?model=app_settings',
          headers: {'Authorization': 'Bearer $adminToken'},
        );
        expect(response.statusCode, 403);
      });
    });
  });
}
