import 'dart:async';

import 'package:core/core.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

/// {@template token_blacklist_service}
/// Defines the interface for a service that manages a blacklist of
/// invalidated authentication tokens (typically identified by their JWT ID - jti).
/// {@endtemplate}
abstract class TokenBlacklistService {
  /// Adds a token identifier (jti) to the blacklist.
  ///
  /// - [jti]: The unique identifier of the token to blacklist.
  /// - [expiry]: The original expiry time of the token. The jti should be
  ///   removed from the blacklist after this time.
  ///
  /// Throws [OperationFailedException] if adding to the blacklist fails.
  Future<void> blacklist(String jti, DateTime expiry);

  /// Checks if a token identifier (jti) is currently blacklisted.
  ///
  /// - [jti]: The unique identifier of the token to check.
  ///
  /// Returns `true` if the jti is blacklisted and its expiry time has not
  /// yet passed, `false` otherwise.
  /// Throws [OperationFailedException] if checking the blacklist fails.
  Future<bool> isBlacklisted(String jti);

  /// Cleans up expired entries from the blacklist.
  /// Implementations might call this periodically.
  Future<void> cleanupExpired();

  /// Disposes of any resources used by the service (e.g., timers).
  void dispose();
}

/// {@template in_memory_token_blacklist_service}
/// An in-memory implementation of [TokenBlacklistService].
///
/// Stores blacklisted JWT IDs (jti) and their expiry times in a map.
/// Includes a periodic cleanup mechanism to remove expired entries.
///
/// **Note:** This implementation is not persistent. The blacklist will be
/// cleared if the server restarts. Use a persistent store (e.g., Redis)
/// for production environments.
/// {@endtemplate}
class InMemoryTokenBlacklistService implements TokenBlacklistService {
  /// {@macro in_memory_token_blacklist_service}
  ///
  /// - [cleanupInterval]: How often the service checks for and removes
  ///   expired token IDs. Defaults to 1 hour.
  InMemoryTokenBlacklistService({
    required Logger log,
    Duration cleanupInterval = const Duration(hours: 1),
  }) : _log = log {
    _cleanupTimer = Timer.periodic(cleanupInterval, (_) async {
      try {
        await cleanupExpired();
      } catch (e) {
        // Log error during cleanup, but don't let it crash the timer
        _log.severe('Error during scheduled cleanup: $e');
      }
    });
    _log.info(
      'Initialized with cleanup interval: '
      '$cleanupInterval',
    );
  }

  /// Stores jti -> expiry DateTime
  @visibleForTesting
  final Map<String, DateTime> blacklistStore = {};
  Timer? _cleanupTimer;
  bool _isDisposed = false;
  final Logger _log;

  @override
  Future<void> blacklist(String jti, DateTime expiry) async {
    if (_isDisposed) {
      _log.warning('Attempted to blacklist on disposed service.');
      return;
    }
    // Simulate async operation
    await Future<void>.delayed(Duration.zero);
    try {
      blacklistStore[jti] = expiry;
      _log.info(
        'Blacklisted jti: $jti '
        '(expires: $expiry)',
      );
    } catch (e) {
      _log.severe('Error adding jti $jti to store: $e');
      throw OperationFailedException('Failed to add token to blacklist: $e');
    }
  }

  @override
  Future<bool> isBlacklisted(String jti) async {
    if (_isDisposed) {
      _log.warning('Attempted to check blacklist on disposed service.');
      return false;
    }
    // Simulate async operation
    await Future<void>.delayed(Duration.zero);
    try {
      final expiry = blacklistStore[jti];
      if (expiry == null) {
        return false;
      }

      final isExpired = DateTime.now().isAfter(expiry);
      if (isExpired) {
        // Expired entry, treat as not blacklisted for practical purposes.
        // Cleanup will eventually remove it.
        return false;
      }
      return true;
    } catch (e) {
      _log.severe('Error checking blacklist for jti $jti: $e');
      throw OperationFailedException('Failed to check token blacklist: $e');
    }
  }

  @override
  Future<void> cleanupExpired() async {
    if (_isDisposed) {
      _log.warning('Attempted cleanup on disposed service.');
      return;
    }
    await Future<void>.delayed(Duration.zero);
    final now = DateTime.now();
    final expiredKeys = <String>[];

    try {
      blacklistStore.forEach((jti, expiry) {
        if (now.isAfter(expiry)) {
          expiredKeys.add(jti);
        }
      });

      if (expiredKeys.isNotEmpty) {
        expiredKeys.forEach(blacklistStore.remove);
        _log.info(
          'Cleaned up ${expiredKeys.length} '
          'expired jti entries.',
        );
      } else {
        _log.finer('Cleanup ran, no expired entries found.');
      }
    } catch (e) {
      _log.severe('Error during cleanup process: $e');
      // Optionally rethrow or handle as an internal error
      // For now, just log it to prevent crashing the cleanup timer.
    }
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _cleanupTimer?.cancel();
      blacklistStore.clear();
      _log.info('Disposed.');
    }
  }
}
