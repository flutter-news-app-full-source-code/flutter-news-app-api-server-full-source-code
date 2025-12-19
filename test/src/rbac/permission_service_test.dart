import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';
import 'package:test/test.dart';

void main() {
  group('PermissionService', () {
    late PermissionService permissionService;

    setUp(() {
      permissionService = const PermissionService();
    });

    // Helper to create a user with specific roles
    User createUser({
      AppUserRole appRole = AppUserRole.guestUser,
      DashboardUserRole dashboardRole = DashboardUserRole.none,
    }) {
      return User(
        id: 'user-id',
        email: 'test@example.com',
        appRole: appRole,
        dashboardRole: dashboardRole,
        feedDecoratorStatus: const {},
        createdAt: DateTime.now(),
      );
    }

    test('isAdmin returns true for admin dashboard role', () {
      final adminUser = createUser(dashboardRole: DashboardUserRole.admin);
      expect(permissionService.isAdmin(adminUser), isTrue);
    });

    test('isAdmin returns false for non-admin dashboard roles', () {
      final publisherUser = createUser(
        dashboardRole: DashboardUserRole.publisher,
      );
      final standardUser = createUser(dashboardRole: DashboardUserRole.none);
      expect(permissionService.isAdmin(publisherUser), isFalse);
      expect(permissionService.isAdmin(standardUser), isFalse);
    });

    test('admin user has all permissions implicitly', () {
      final adminUser = createUser(dashboardRole: DashboardUserRole.admin);
      // Test a permission that only admins have
      expect(
        permissionService.hasPermission(adminUser, Permissions.userUpdate),
        isTrue,
      );
      // Test a permission that admins inherit from publisher
      expect(
        permissionService.hasPermission(adminUser, Permissions.headlineCreate),
        isTrue,
      );
      // Test a permission from the app roles
      expect(
        permissionService.hasPermission(adminUser, Permissions.headlineRead),
        isTrue,
      );
    });

    test(
      'publisher user has publisher permissions but not admin permissions',
      () {
        final publisherUser = createUser(
          dashboardRole: DashboardUserRole.publisher,
        );
        expect(
          permissionService.hasPermission(
            publisherUser,
            Permissions.headlineCreate,
          ),
          isTrue,
        );
        expect(
          permissionService.hasPermission(
            publisherUser,
            Permissions.userUpdate,
          ),
          isFalse,
        );
      },
    );

    test(
      'standard app user has app permissions but not dashboard permissions',
      () {
        final standardUser = createUser(appRole: AppUserRole.standardUser);
        expect(
          permissionService.hasPermission(
            standardUser,
            Permissions.userReadOwned,
          ),
          isTrue,
        );
        expect(
          permissionService.hasPermission(
            standardUser,
            Permissions.headlineCreate,
          ),
          isFalse,
        );
      },
    );

    test('user with combined roles has combined permissions', () {
      final user = createUser(
        appRole: AppUserRole.standardUser,
        dashboardRole: DashboardUserRole.publisher,
      );
      // Has app permission
      expect(
        permissionService.hasPermission(user, Permissions.userReadOwned),
        isTrue,
      );
      // Has dashboard permission
      expect(
        permissionService.hasPermission(user, Permissions.headlineCreate),
        isTrue,
      );
      // Does not have admin permission
      expect(
        permissionService.hasPermission(user, Permissions.userUpdate),
        isFalse,
      );
    });

    test('returns false for a permission the user does not have', () {
      final guestUser = createUser(appRole: AppUserRole.guestUser);
      // Guests can read headlines but not create them
      expect(
        permissionService.hasPermission(guestUser, Permissions.headlineRead),
        isTrue,
      );
      expect(
        permissionService.hasPermission(guestUser, Permissions.headlineCreate),
        isFalse,
      );
    });
  });
}
