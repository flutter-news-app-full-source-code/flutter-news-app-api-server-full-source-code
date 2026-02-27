import 'dart:mirrors';

import 'package:flutter_news_app_backend_api_full_source_code/src/rbac/permissions.dart';
import 'package:test/test.dart';

void main() {
  group('Permissions Constants', () {
    test('All permission strings are unique', () {
      final classMirror = reflectClass(Permissions);
      final permissionValues = <String>[];

      for (final declaration in classMirror.declarations.values) {
        if (declaration is VariableMirror &&
            declaration.isStatic &&
            declaration.isConst) {
          final value =
              classMirror.getField(declaration.simpleName).reflectee as String;
          permissionValues.add(value);
        }
      }

      final uniqueValues = permissionValues.toSet();
      expect(
        uniqueValues.length,
        equals(permissionValues.length),
        reason:
            'Duplicate permission strings found. Permissions must be unique.',
      );
    });

    test('Permission strings follow resource.action format', () {
      final classMirror = reflectClass(Permissions);
      for (final declaration in classMirror.declarations.values) {
        if (declaration is VariableMirror &&
            declaration.isStatic &&
            declaration.isConst) {
          final value =
              classMirror.getField(declaration.simpleName).reflectee as String;

          // Regex enforces: lowercase_resource.lowercase_action
          // e.g., "headline.read", "user_profile.update"
          expect(
            value,
            matches(RegExp(r'^[a-z_]+\.[a-z_]+$')),
            reason:
                'Permission "$value" does not match format "resource.action"',
          );
        }
      }
    });
  });
}
