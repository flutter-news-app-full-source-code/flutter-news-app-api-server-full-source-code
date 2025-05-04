import 'dart:async';
import 'dart:math';

import 'package:ht_shared/ht_shared.dart'; // For exceptions

/// {@template verification_code_storage_service}
/// Service responsible for storing, retrieving, and validating temporary
/// verification codes, typically used for email or phone number verification.
/// {@endtemplate}
abstract class VerificationCodeStorageService {
  /// {@macro verification_code_storage_service}
  const VerificationCodeStorageService();

  /// Generates a verification code (e.g., 6 digits) and stores it associated
  /// with the given identifier (e.g., email address).
  ///
  /// Sets an expiry time for the code.
  /// Returns the generated code.
  /// Throws [OperationFailedException] if code generation or storage fails.
  Future<String> generateAndStoreCode(
    String identifier, {
    Duration expiry = const Duration(minutes: 10),
  });

  /// Validates the provided code against the stored code for the identifier.
  ///
  /// Returns `true` if the code is valid and not expired, `false` otherwise.
  /// Implementations should typically remove the code after successful validation
  /// to prevent reuse.
  /// Throws [OperationFailedException] for unexpected validation errors.
  Future<bool> validateCode(String identifier, String code);

  /// Removes the stored code for the given identifier, if any.
  Future<void> removeCode(String identifier);
}

/// In-memory implementation of [VerificationCodeStorageService].
///
/// **Note:** This is suitable for single-instance development/testing only.
/// It does not persist codes and will lose them on server restart.
/// For production, use a persistent store like Redis or a database table.
class InMemoryVerificationCodeStorageService
    implements VerificationCodeStorageService {
  /// {@macro in_memory_verification_code_storage_service}
  InMemoryVerificationCodeStorageService() {
    // Start a periodic timer to clean up expired codes
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 5), // Check every 5 minutes
      (_) => _cleanupExpiredCodes(),
    );
  }

  // Stores the code and its expiry time.
  final Map<String, ({String code, DateTime expiry})> _storage = {};
  final Random _random = Random();
  Timer? _cleanupTimer;

  @override
  Future<String> generateAndStoreCode(
    String identifier, {
    Duration expiry = const Duration(minutes: 10),
  }) async {
    // Generate a 6-digit code
    final code = List.generate(6, (_) => _random.nextInt(10)).join();
    final expiryTime = DateTime.now().add(expiry);

    _storage[identifier] = (code: code, expiry: expiryTime);
    print(
      'Stored code $code for $identifier, expires at $expiryTime',
    );
    await Future<void>.delayed(Duration.zero); // Simulate async
    return code;
  }

  @override
  Future<bool> validateCode(String identifier, String code) async {
    final storedEntry = _storage[identifier];
    await Future<void>.delayed(Duration.zero); // Simulate async

    if (storedEntry == null) {
      print('Validation failed: No code found for $identifier');
      return false; // No code stored for this identifier
    }

    if (DateTime.now().isAfter(storedEntry.expiry)) {
      print('Validation failed: Code expired for $identifier');
      _storage.remove(identifier); // Remove expired code
      return false; // Code expired
    }

    if (storedEntry.code == code) {
      print('Validation successful for $identifier');
      // Code is valid, remove it to prevent reuse
      _storage.remove(identifier);
      return true;
    } else {
      print(
        'Validation failed: Invalid code "$code" for $identifier '
        '(expected "${storedEntry.code}")',
      );
      return false; // Code does not match
    }
  }

  @override
  Future<void> removeCode(String identifier) async {
    _storage.remove(identifier);
    await Future<void>.delayed(Duration.zero); // Simulate async
    print('Removed code for $identifier');
  }

  void _cleanupExpiredCodes() {
    final now = DateTime.now();
    _storage.removeWhere((identifier, entry) {
      final isExpired = now.isAfter(entry.expiry);
      if (isExpired) {
        print('Cleaning up expired code for $identifier');
      }
      return isExpired;
    });
  }

  /// Call this method when the server is shutting down to stop the timer.
  void dispose() {
    _cleanupTimer?.cancel();
    _storage.clear();
    print('VerificationCodeStorageService disposed.');
  }
}
