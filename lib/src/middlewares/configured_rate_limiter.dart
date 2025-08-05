import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/rate_limiter_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';

/// A key extractor that uses the authenticated user's ID.
///
/// This should be used for routes that are protected by authentication,
/// ensuring that the rate limit is applied on a per-user basis.
Future<String?> _userKeyExtractor(RequestContext context) async {
  return context.read<User>().id;
}

/// A role-aware middleware factory that applies a rate limit only if the
/// authenticated user does not have the `rateLimiting.bypass` permission.
Middleware _createRoleAwareRateLimiter({
  required int limit,
  required Duration window,
  required Future<String?> Function(RequestContext) keyExtractor,
}) {
  return (handler) {
    return (context) {
      // Read dependencies from the context.
      final permissionService = context.read<PermissionService>();
      final user = context.read<User>(); // Assumes user is authenticated

      // Check for the bypass permission.
      if (permissionService.hasPermission(user, Permissions.rateLimitingBypass)) {
        // If the user has the bypass permission, skip the rate limiter.
        return handler(context);
      }

      // If the user does not have the bypass permission, apply the rate limiter.
      return rateLimiter(
        limit: limit,
        window: window,
        keyExtractor: keyExtractor,
      )(handler)(context);
    };
  };
}

/// Creates a pre-configured, role-aware rate limiter for READ operations.
///
/// This middleware will:
/// 1. Check if the authenticated user has the `rateLimiting.bypass` permission.
///    If so, the check is skipped.
/// 2. If not, it applies the rate limit defined by `RATE_LIMIT_READ_LIMIT`
///    and `RATE_LIMIT_READ_WINDOW_MINUTES` from the environment.
/// 3. It uses the authenticated user's ID as the key for the rate limit.
Middleware createReadRateLimiter() {
  return _createRoleAwareRateLimiter(
    limit: EnvironmentConfig.rateLimitReadLimit,
    window: EnvironmentConfig.rateLimitReadWindow,
    keyExtractor: _userKeyExtractor,
  );
}

/// Creates a pre-configured, role-aware rate limiter for WRITE operations.
///
/// This middleware will:
/// 1. Check if the authenticated user has the `rateLimiting.bypass` permission.
///    If so, the check is skipped.
/// 2. If not, it applies the stricter rate limit defined by
///    `RATE_LIMIT_WRITE_LIMIT` and `RATE_LIMIT_WRITE_WINDOW_MINUTES` from
///    the environment.
/// 3. It uses the authenticated user's ID as the key for the rate limit.
Middleware createWriteRateLimiter() {
  return _createRoleAwareRateLimiter(
    limit: EnvironmentConfig.rateLimitWriteLimit,
    window: EnvironmentConfig.rateLimitWriteWindow,
    keyExtractor: _userKeyExtractor,
  );
}
