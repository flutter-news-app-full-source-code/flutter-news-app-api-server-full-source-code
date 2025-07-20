// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'dart:math';

import 'package:ht_shared/ht_shared.dart';
import 'package:meta/meta.dart';

// Default duration for code expiry (e.g., 15 minutes)
const _defaultCodeExpiryDuration = Duration(minutes: 15);
// Default interval for cleaning up expired codes (e.g., 1 hour)
const _defaultCleanupInterval = Duration(hours: 1);

/// {@template code_entry_base}
/// Base class for storing verification code entries.
/// {@endtemplate}
class _CodeEntryBase {
  /// {@macro code_entry_base}
  _CodeEntryBase(this.code, this.expiresAt);

  final String code;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// {@template sign_in_code_entry}
/// Stores a verification code for standard email sign-in.
/// {@endtemplate}
class _SignInCodeEntry extends _CodeEntryBase {
  /// {@macro sign_in_code_entry}
  _SignInCodeEntry(super.code, super.expiresAt);
}

/// {@template verification_code_storage_service}
/// Defines the interface for a service that manages verification codes
/// for different authentication flows (sign-in and account linking).
/// {@endtemplate}
abstract class VerificationCodeStorageService {
  /// {@macro verification_code_storage_service}
  const VerificationCodeStorageService();

  // --- For Standard Email+Code Sign-In/Sign-Up ---

  /// Generates, stores, and returns a verification code for a standard sign-in
  /// attempt associated with the given [email].
  /// Codes are typically 6 digits.
  /// Throws [OperationFailedException] on storage failure.
  Future<String> generateAndStoreSignInCode(String email);

  /// Validates a sign-in [code] against the one stored for the given [email].
  /// Returns `true` if valid and not expired, `false` otherwise.
  /// Throws [OperationFailedException] on validation failure if an unexpected
  /// error occurs during the check.
  Future<bool> validateSignInCode(String email, String code);

  /// Clears any sign-in code associated with the given [email].
  /// Throws [OperationFailedException] if clearing fails.
  Future<void> clearSignInCode(String email);

  // --- General ---

  /// Periodically cleans up expired codes of all types.
  /// This method is typically called internally by implementations with a timer.
  Future<void> cleanupExpiredCodes();

  /// Disposes of any resources used by the service (e.g., timers for cleanup).
  void dispose();
}

/// {@template in_memory_verification_code_storage_service}
/// An in-memory implementation of [VerificationCodeStorageService].
///
/// Stores verification codes in memory. Not suitable for production if
/// persistence across server restarts is required.
/// {@endtemplate}
class InMemoryVerificationCodeStorageService
    implements VerificationCodeStorageService {
  /// {@macro in_memory_verification_code_storage_service}
  InMemoryVerificationCodeStorageService({
    Duration cleanupInterval = _defaultCleanupInterval,
    this.codeExpiryDuration = _defaultCodeExpiryDuration,
  }) {
    _cleanupTimer = Timer.periodic(cleanupInterval, (_) async {
      try {
        await cleanupExpiredCodes();
      } catch (e) {
        print(
          '[InMemoryVerificationCodeStorageService] Error during scheduled cleanup: $e',
        );
      }
    });
    print(
      '[InMemoryVerificationCodeStorageService] Initialized with cleanup interval: '
      '$cleanupInterval and code expiry: $codeExpiryDuration',
    );
  }

  /// Duration for which generated codes are considered valid.
  final Duration codeExpiryDuration;

  /// Store for standard sign-in codes: Key is email.
  @visibleForTesting
  final Map<String, _SignInCodeEntry> signInCodesStore = {};

  Timer? _cleanupTimer;
  bool _isDisposed = false;
  final Random _random = Random();

  String _generateNumericCode({int length = 6}) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(_random.nextInt(10).toString());
    }
    return buffer.toString();
  }

  @override
  Future<String> generateAndStoreSignInCode(String email) async {
    if (_isDisposed) {
      throw const OperationFailedException('Service is disposed.');
    }
    await Future<void>.delayed(Duration.zero); // Simulate async
    final code = _generateNumericCode();
    final expiresAt = DateTime.now().add(codeExpiryDuration);
    signInCodesStore[email] = _SignInCodeEntry(code, expiresAt);
    print(
      '[InMemoryVerificationCodeStorageService] Stored sign-in code: $code for $email (expires: $expiresAt)',
    );
    return code;
  }

  @override
  Future<bool> validateSignInCode(String email, String code) async {
    if (_isDisposed) return false;
    await Future<void>.delayed(Duration.zero); // Simulate async
    final entry = signInCodesStore[email];
    if (entry == null || entry.isExpired || entry.code != code) {
      return false;
    }
    return true;
  }

  @override
  Future<void> clearSignInCode(String email) async {
    if (_isDisposed) return;
    await Future<void>.delayed(Duration.zero); // Simulate async
    signInCodesStore.remove(email);
    print(
      '[InMemoryVerificationCodeStorageService] Cleared sign-in code for $email',
    );
  }

  @override
  Future<void> cleanupExpiredCodes() async {
    if (_isDisposed) return;
    await Future<void>.delayed(Duration.zero); // Simulate async
    var cleanedCount = 0;

    signInCodesStore.removeWhere((key, entry) {
      if (entry.isExpired) {
        cleanedCount++;
        return true;
      }
      return false;
    });

    if (cleanedCount > 0) {
      print(
        '[InMemoryVerificationCodeStorageService] Cleaned up $cleanedCount expired codes.',
      );
    }
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _cleanupTimer?.cancel();
      signInCodesStore.clear();
      print('[InMemoryVerificationCodeStorageService] Disposed.');
    }
  }
}
