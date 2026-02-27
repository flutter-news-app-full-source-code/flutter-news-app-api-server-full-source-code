import 'package:core/core.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/rbac/permissions.dart';
import 'package:test/test.dart';

void main() {
  group('PermissionService', () {
    late PermissionService permissionService;

    setUp(() {
      permissionService = const PermissionService();
    });

    // Helper to create a user with specific roles
    User createUser({
      UserRole role = UserRole.user,
      AccessTier tier = AccessTier.standard,
    }) {
      return User(
        id: 'user-id',
        email: 'test@example.com',
        role: role,
        tier: tier,
        createdAt: DateTime.now(),
      );
    }

    test('isAdmin returns true for admin role', () {
      final adminUser = createUser(role: UserRole.admin);
      expect(permissionService.isAdmin(adminUser), isTrue);
    });

    test('isAdmin returns false for non-admin roles', () {
      final publisherUser = createUser(role: UserRole.publisher);
      final standardUser = createUser(role: UserRole.user);
      expect(permissionService.isAdmin(publisherUser), isFalse);
      expect(permissionService.isAdmin(standardUser), isFalse);
    });

    test('admin user has all permissions implicitly', () {
      final adminUser = createUser(role: UserRole.admin);
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
      'publisher user has publisher permissions but not admin-only permissions',
      () {
        final publisherUser = createUser(role: UserRole.publisher);
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
      'standard user has standard tier permissions but not publisher permissions',
      () {
        final standardUser = createUser(tier: AccessTier.standard);
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

    test('user with combined role and tier has combined permissions', () {
      final user = createUser(
        tier: AccessTier.standard,
        role: UserRole.publisher,
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
      final guestUser = createUser(tier: AccessTier.guest);
      // Guests can read headlines (public) but not create them
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
