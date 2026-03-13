import 'package:test/test.dart';
import 'package:veritai_api/src/rbac/permissions.dart';

void main() {
  group('Permissions Constants', () {
    const allPermissions = [
      Permissions.headlineCreate,
      Permissions.headlineRead,
      Permissions.headlineUpdate,
      Permissions.headlineDelete,
      Permissions.topicCreate,
      Permissions.topicRead,
      Permissions.topicUpdate,
      Permissions.topicDelete,
      Permissions.sourceCreate,
      Permissions.sourceRead,
      Permissions.sourceUpdate,
      Permissions.sourceDelete,
      Permissions.countryCreate,
      Permissions.countryRead,
      Permissions.countryUpdate,
      Permissions.countryDelete,
      Permissions.languageCreate,
      Permissions.languageRead,
      Permissions.languageUpdate,
      Permissions.languageDelete,
      Permissions.userRead,
      Permissions.userReadOwned,
      Permissions.userUpdateOwned,
      Permissions.userDeleteOwned,
      Permissions.userUpdate,
      Permissions.appSettingsReadOwned,
      Permissions.appSettingsUpdateOwned,
      Permissions.userContentPreferencesReadOwned,
      Permissions.userContentPreferencesUpdateOwned,
      Permissions.userContextReadOwned,
      Permissions.userContextUpdateOwned,
      Permissions.userRewardsReadOwned,
      Permissions.remoteConfigCreate,
      Permissions.remoteConfigRead,
      Permissions.remoteConfigUpdate,
      Permissions.remoteConfigDelete,
      Permissions.dashboardLogin,
      Permissions.userPreferenceBypassLimits,
      Permissions.rateLimitingBypass,
      Permissions.pushNotificationSendBreakingNews,
      Permissions.pushNotificationDeviceCreateOwned,
      Permissions.pushNotificationDeviceDeleteOwned,
      Permissions.pushNotificationDeviceReadOwned,
      Permissions.inAppNotificationReadOwned,
      Permissions.inAppNotificationUpdateOwned,
      Permissions.inAppNotificationDeleteOwned,
      Permissions.engagementCreateOwned,
      Permissions.engagementReadOwned,
      Permissions.engagementUpdateOwned,
      Permissions.engagementDeleteOwned,
      Permissions.reportCreateOwned,
      Permissions.reportReadOwned,
      Permissions.appReviewCreateOwned,
      Permissions.appReviewReadOwned,
      Permissions.appReviewUpdateOwned,
      Permissions.analyticsRead,
      Permissions.mediaRequestUploadUrl,
      Permissions.mediaManage,
      Permissions.intelligenceEnrich,
    ];

    test('All permission strings are unique', () {
      final uniqueValues = allPermissions.toSet();
      expect(
        uniqueValues.length,
        equals(allPermissions.length),
        reason:
            'Duplicate permission strings found. Permissions must be unique.',
      );
    });

    test('Permission strings follow resource.action format', () {
      for (final permission in allPermissions) {
        // Regex enforces: lowercase_resource.lowercase_action
        expect(
          permission,
          matches(RegExp(r'^[a-z_]+\.[a-z_]+$')),
          reason:
              'Permission "$permission" does not match format "resource.action"',
        );
      }
    });
  });
}
