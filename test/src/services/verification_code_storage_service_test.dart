import 'package:ht_api/src/services/verification_code_storage_service.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryVerificationCodeStorageService', () {
    late InMemoryVerificationCodeStorageService service;
    const testIdentifier = 'test@example.com';
    const shortExpiry = Duration(milliseconds: 50); // Short expiry for testing

    setUp(() {
      service = InMemoryVerificationCodeStorageService();
    });

    tearDown(() {
      service.dispose(); // Ensure cleanup timer is cancelled
    });

    test('generateAndStoreCode returns a 6-digit code and stores it', () async {
      final code = await service.generateAndStoreCode(testIdentifier);

      expect(code, isA<String>());
      expect(code.length, equals(6));
      expect(int.tryParse(code), isNotNull); // Check if it's numeric

      // Validate internally (should succeed immediately after generation)
      final isValid = await service.validateCode(testIdentifier, code);
      // Note: validateCode removes the code upon success, so we can't re-validate
      expect(isValid, isTrue);

      // Check if removed after validation
      final isValidAgain = await service.validateCode(testIdentifier, code);
      expect(isValidAgain, isFalse);
    });

    test('validateCode returns true for correct code within expiry', () async {
      final code = await service.generateAndStoreCode(
        testIdentifier,
        expiry: const Duration(seconds: 1), // Longer expiry for this test
      );
      final isValid = await service.validateCode(testIdentifier, code);
      expect(isValid, isTrue);
    });

    test('validateCode returns false for incorrect code', () async {
      await service.generateAndStoreCode(testIdentifier);
      final isValid = await service.validateCode(testIdentifier, '000000');
      expect(isValid, isFalse);
    });

    test('validateCode returns false for expired code', () async {
      final code = await service.generateAndStoreCode(
        testIdentifier,
        expiry: shortExpiry,
      );
      // Wait for the code to expire
      await Future<void>.delayed(shortExpiry * 1.5);
      final isValid = await service.validateCode(testIdentifier, code);
      expect(isValid, isFalse);
    });

    test('validateCode returns false for non-existent identifier', () async {
      final isValid =
          await service.validateCode('nonexistent@example.com', '123456');
      expect(isValid, isFalse);
    });

    test('validateCode removes code after successful validation', () async {
      final code = await service.generateAndStoreCode(
        testIdentifier,
        expiry: const Duration(seconds: 1),
      );
      // First validation succeeds and removes code
      final isValidFirst = await service.validateCode(testIdentifier, code);
      expect(isValidFirst, isTrue);

      // Second validation fails because code was removed
      final isValidSecond = await service.validateCode(testIdentifier, code);
      expect(isValidSecond, isFalse);
    });

    test('removeCode removes the stored code', () async {
      final code = await service.generateAndStoreCode(testIdentifier);
      await service.removeCode(testIdentifier);
      final isValid = await service.validateCode(testIdentifier, code);
      expect(isValid, isFalse); // Should be false as code was removed
    });

    test('removeCode does nothing for non-existent identifier', () async {
      // Expect no errors when removing a non-existent code
      await expectLater(
        () => service.removeCode('nonexistent@example.com'),
        completes,
      );
    });

    // Note: Testing the automatic cleanup timer (`_cleanupExpiredCodes`)
    // directly is tricky without exposing internal state or using more
    // advanced testing techniques like fake_async.
    // However, the 'validateCode returns false for expired code' test
    // implicitly verifies that expired codes are handled correctly,
    // either by direct expiry check or eventual cleanup.
  });
}
