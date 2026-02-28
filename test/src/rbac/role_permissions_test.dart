import 'package:core/core.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/rbac/permissions.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/rbac/role_permissions.dart';
import 'package:test/test.dart';

void main() {
  group('Role Permissions Configuration', () {
    test('All AccessTiers are mapped', () {
      for (final tier in AccessTier.values) {
        expect(
          rolePermissions.containsKey(tier),
          isTrue,
          reason: 'AccessTier.$tier should have a permission set defined.',
        );
      }
    });

    test('All UserRoles are mapped', () {
      for (final role in UserRole.values) {
        expect(
          rolePermissions.containsKey(role),
          isTrue,
          reason: 'UserRole.$role should have a permission set defined.',
        );
      }
    });

    test('Standard tier includes Guest permissions', () {
      final guestPerms = rolePermissions[AccessTier.guest]!;
      final standardPerms = rolePermissions[AccessTier.standard]!;

      expect(standardPerms.containsAll(guestPerms), isTrue);
    });

    test('Admin role includes Publisher permissions', () {
      final publisherPerms = rolePermissions[UserRole.publisher]!;
      final adminPerms = rolePermissions[UserRole.admin]!;

      expect(adminPerms.containsAll(publisherPerms), isTrue);
    });

    test('Specific permissions are assigned correctly', () {
      // Check a sample permission for each level to ensure mapping isn't empty
      expect(
        rolePermissions[AccessTier.guest],
        contains(Permissions.headlineRead),
      );
      expect(
        rolePermissions[AccessTier.standard],
        contains(Permissions.userReadOwned),
      );
      expect(
        rolePermissions[UserRole.publisher],
        contains(Permissions.headlineCreate),
      );
    });
  });
}
