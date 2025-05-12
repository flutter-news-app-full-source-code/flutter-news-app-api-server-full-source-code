import 'dart:async';
import 'dart:math';

import 'package:ht_shared/ht_shared.dart'; // For HtHttpException, ConflictException
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

/// {@template link_code_entry}
/// Stores a verification code for linking an email to an existing user.
/// {@endtemplate}
class _LinkCodeEntry extends _CodeEntryBase {
  /// {@macro link_code_entry}
  _LinkCodeEntry(super.code, super.expiresAt, this.emailToLink);

  /// The email address this link code is intended to verify.
  final String emailToLink;
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

  // --- For Linking an Email to an Existing Authenticated (Anonymous) User ---

  /// Generates, stores, and returns a verification code for linking
  /// [emailToLink] to the account of [userId].
  /// The [userId] is that of the currently authenticated anonymous user.
  /// Codes are typically 6 digits.
  /// Throws [OperationFailedException] on storage failure.
  /// Throws [ConflictException] if [emailToLink] is already actively pending
  /// for linking by another user, or if this [userId] already has an active
  /// link code pending.
  Future<String> generateAndStoreLinkCode({
    required String userId,
    required String emailToLink,
  });

  /// Validates the [linkCode] provided by the user with [userId] who is
  /// attempting to link an email.
  /// Returns the [emailToLink] if the code is valid and matches the one
  /// stored for this [userId]. Returns `null` if invalid or expired.
  /// Throws [OperationFailedException] on validation failure if an unexpected
  /// error occurs during the check.
  Future<String?> validateAndRetrieveLinkedEmail({
    required String userId,
    required String linkCode,
  });

  /// Clears any pending link-code data associated with [userId].
  /// Throws [OperationFailedException] if clearing fails.
  Future<void> clearLinkCode(String userId);

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

  // Store for standard sign-in codes: Key is email.
  @visibleForTesting
  final Map<String, _SignInCodeEntry> signInCodesStore = {};

  // Store for account linking codes: Key is userId.
  @visibleForTesting
  final Map<String, _LinkCodeEntry> linkCodesStore = {};

  Timer? _cleanupTimer;
  bool _isDisposed = false;
  final Random _random = Random();

  String _generateNumericCode({int length = 6}) {
    var code = '';
    for (var i = 0; i < length; i++) {
      code += _random.nextInt(10).toString();
    }
    return code;
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
      '[InMemoryVerificationCodeStorageService] Stored sign-in code for $email (expires: $expiresAt)',
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
  Future<String> generateAndStoreLinkCode({
    required String userId,
    required String emailToLink,
  }) async {
    if (_isDisposed) {
      throw const OperationFailedException('Service is disposed.');
    }
    await Future<void>.delayed(Duration.zero); // Simulate async

    // Check if this userId already has a pending link code
    if (linkCodesStore.containsKey(userId) &&
        !linkCodesStore[userId]!.isExpired) {
      throw const ConflictException(
        'User already has an active email linking process pending.',
      );
    }
    // Check if emailToLink is already pending for another user
    final isEmailPendingForOther = linkCodesStore.values.any(
      (entry) =>
          entry.emailToLink == emailToLink &&
          !entry.isExpired &&
          linkCodesStore.keys.firstWhere((id) => linkCodesStore[id] == entry) !=
              userId,
    );
    if (isEmailPendingForOther) {
      throw ConflictException(
        'Email is already pending verification for another account linking process.',
      );
    }

    final code = _generateNumericCode();
    final expiresAt = DateTime.now().add(codeExpiryDuration);
    linkCodesStore[userId] = _LinkCodeEntry(code, expiresAt, emailToLink);
    print(
      '[InMemoryVerificationCodeStorageService] Stored link code for user $userId, email $emailToLink (expires: $expiresAt)',
    );
    return code;
  }

  @override
  Future<String?> validateAndRetrieveLinkedEmail({
    required String userId,
    required String linkCode,
  }) async {
    if (_isDisposed) return null;
    await Future<void>.delayed(Duration.zero); // Simulate async
    final entry = linkCodesStore[userId];
    if (entry == null || entry.isExpired || entry.code != linkCode) {
      return null;
    }
    return entry.emailToLink; // Return the email associated with this valid code
  }

  @override
  Future<void> clearLinkCode(String userId) async {
    if (_isDisposed) return;
    await Future<void>.delayed(Duration.zero); // Simulate async
    linkCodesStore.remove(userId);
    print(
      '[InMemoryVerificationCodeStorageService] Cleared link code for user $userId',
    );
  }

  @override
  Future<void> cleanupExpiredCodes() async {
    if (_isDisposed) return;
    await Future<void>.delayed(Duration.zero); // Simulate async
    final now = DateTime.now();
    var cleanedCount = 0;

    signInCodesStore.removeWhere((key, entry) {
      if (entry.isExpired) {
        cleanedCount++;
        return true;
      }
      return false;
    });

    linkCodesStore.removeWhere((key, entry) {
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
      linkCodesStore.clear();
      print('[InMemoryVerificationCodeStorageService] Disposed.');
    }
  }
}
