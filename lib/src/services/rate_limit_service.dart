import 'package:core/core.dart';

/// {@template rate_limit_service}
/// Defines the interface for a service that provides rate-limiting capabilities.
///
/// This service is used to check and record requests against a specific key
/// (e.g., an IP address or email) to prevent abuse of sensitive or expensive
/// endpoints.
/// {@endtemplate}
abstract class RateLimitService {
  /// {@macro rate_limit_service}
  const RateLimitService();

  /// Checks if a request associated with the given [key] is allowed.
  ///
  /// This method performs the following logic:
  /// 1. Counts the number of recent requests for the [key] within the [window].
  /// 2. If the count is greater than or equal to the [limit], it throws a
  ///    [ForbiddenException] indicating the rate limit has been exceeded.
  /// 3. If the count is below the limit, it records the current request
  ///    (e.g., by storing a timestamp) and allows the request to proceed.
  ///
  /// - [key]: A unique identifier for the request source (e.g., IP address).
  /// - [limit]: The maximum number of requests allowed within the window.
  /// - [window]: The time duration to consider for counting requests.
  ///
  /// Throws [ForbiddenException] if the rate limit is exceeded.
  /// Throws [OperationFailedException] for unexpected errors during the check.
  Future<void> checkRequest({
    required String key,
    required int limit,
    required Duration window,
  });

  /// Disposes of any resources used by the service (e.g., timers).
  void dispose();
}
