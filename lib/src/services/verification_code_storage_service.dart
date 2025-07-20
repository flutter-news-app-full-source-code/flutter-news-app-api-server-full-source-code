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
