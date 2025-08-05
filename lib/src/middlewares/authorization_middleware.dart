import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('AuthorizationMiddleware');

/// {@template authorization_middleware}
/// Middleware to enforce role-based permissions.
///
/// This middleware reads the authenticated [User] and a required `permission`
/// string from the request context. It then checks if the user has that
/// permission using the [PermissionService].
///
/// The required permission string must be provided into the context by an
/// earlier middleware, typically one specific to the route group.
///
/// If the user does not have the required permission, it throws a
/// [ForbiddenException], which should be caught by the `errorHandler` middleware.
///
/// This middleware runs *after* authentication.
/// {@endtemplate}
Middleware authorizationMiddleware() {
  return (handler) {
    return (context) async {
      // Read dependencies from the context.
      // User is guaranteed non-null by requireAuthentication() middleware.
      final user = context.read<User>();
      final permissionService = context.read<PermissionService>();
      final permission = context.read<String>();

      if (!permissionService.hasPermission(user, permission)) {
        _log.warning(
          'User ${user.id} denied access to permission "$permission".',
        );
        throw const ForbiddenException(
          'You do not have permission to perform this action.',
        );
      }

      _log.finer(
        'User ${user.id} granted access to permission "$permission".',
      );

      // If the check passes, proceed to the next handler.
      return handler(context);
    };
  };
}
