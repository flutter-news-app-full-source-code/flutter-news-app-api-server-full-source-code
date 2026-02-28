import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/rate_limit_service.dart';

/// Extracts the client's IP address from the request.
///
/// It prioritizes the 'X-Forwarded-For' header, which is standard for
/// identifying the originating IP of a client connecting through a proxy
/// or load balancer. If that header is not present, it falls back to the
/// direct connection's IP address.
String? _getIpAddress(RequestContext context) {
  final headers = context.request.headers;
  // The 'X-Forwarded-For' header can contain a comma-separated list of IPs.
  // The first one is typically the original client IP.
  final xff = headers['X-Forwarded-For']?.split(',').first.trim();
  if (xff != null && xff.isNotEmpty) {
    return xff;
  }
  // Fallback to the direct connection IP if XFF is not available.
  return context.request.connectionInfo.remoteAddress.address;
}

/// Middleware to enforce rate limiting on a route.
///
/// This middleware uses the [RateLimitService] to track and limit the number
/// of requests from a unique source (identified by a key) within a specific
/// time window.
///
/// - [limit]: The maximum number of requests allowed.
/// - [window]: The time duration in which the requests are counted.
/// - [keyExtractor]: A function that extracts a unique key from the request
///   context. This could be an IP address, an email from the body, etc.
Middleware rateLimiter({
  required int limit,
  required Duration window,
  required Future<String?> Function(RequestContext) keyExtractor,
}) {
  return (handler) {
    return (context) async {
      final rateLimitService = context.read<RateLimitService>();
      final key = await keyExtractor(context);

      // If a key cannot be extracted, we bypass the rate limiter.
      // This is a safeguard; for IP-based limiting, a key should always exist.
      if (key == null || key.isEmpty) {
        return handler(context);
      }

      // The checkRequest method will throw a ForbiddenException if the
      // limit is exceeded. This will be caught by the global error handler.
      await rateLimitService.checkRequest(
        key: key,
        limit: limit,
        window: window,
      );

      // If the check passes, proceed to the next handler.
      return handler(context);
    };
  };
}

/// A specific implementation of the keyExtractor for IP-based rate limiting.
Future<String?> ipKeyExtractor(RequestContext context) async {
  return _getIpAddress(context);
}
