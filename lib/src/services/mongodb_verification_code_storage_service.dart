import 'dart:async';
import 'dart:math';

import 'package:ht_api/src/services/verification_code_storage_service.dart';
import 'package:ht_data_mongodb/ht_data_mongodb.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// The name of the MongoDB collection for storing verification codes.
const String kVerificationCodesCollection = 'verification_codes';

/// {@template mongodb_verification_code_storage_service}
/// A MongoDB-backed implementation of [VerificationCodeStorageService].
///
/// Stores verification codes in a dedicated MongoDB collection with a TTL
/// index on an `expiresAt` field for automatic cleanup. It uses a unique
/// index on the `email` field to ensure data integrity.
/// {@endtemplate}
class MongoDbVerificationCodeStorageService
    implements VerificationCodeStorageService {
  /// {@macro mongodb_verification_code_storage_service}
  MongoDbVerificationCodeStorageService({
    required MongoDbConnectionManager connectionManager,
    required Logger log,
    this.codeExpiryDuration = const Duration(minutes: 15),
  }) : _connectionManager = connectionManager,
       _log = log;

  final MongoDbConnectionManager _connectionManager;
  final Logger _log;
  final Random _random = Random();

  /// The duration for which generated codes are considered valid.
  final Duration codeExpiryDuration;

  DbCollection get _collection =>
      _connectionManager.db.collection(kVerificationCodesCollection);

  String _generateNumericCode({int length = 6}) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(_random.nextInt(10).toString());
    }
    return buffer.toString();
  }

  @override
  Future<String> generateAndStoreSignInCode(String email) async {
    final code = _generateNumericCode();
    final expiresAt = DateTime.now().add(codeExpiryDuration);

    try {
      // Use updateOne with upsert: if a document for the email exists,
      // it's updated with a new code and expiry; otherwise, it's created.
      await _collection.updateOne(
        where.eq('email', email),
        modify
            .set('code', code)
            .set('expiresAt', expiresAt)
            .setOnInsert('_id', ObjectId()),
        upsert: true,
      );
      _log.info('Stored sign-in code for $email (expires: $expiresAt)');
      return code;
    } catch (e) {
      _log.severe('Failed to store sign-in code for $email: $e');
      throw OperationFailedException('Failed to store sign-in code: $e');
    }
  }

  @override
  Future<bool> validateSignInCode(String email, String code) async {
    try {
      final entry = await _collection.findOne(where.eq('email', email));
      if (entry == null) {
        return false; // No code found for this email
      }

      final storedCode = entry['code'] as String?;
      final expiresAt = entry['expiresAt'] as DateTime?;

      // The TTL index handles automatic deletion, but this check prevents
      // using a code in the brief window before it's deleted.
      if (storedCode != code ||
          expiresAt == null ||
          DateTime.now().isAfter(expiresAt)) {
        return false; // Code mismatch or expired
      }

      return true;
    } catch (e) {
      _log.severe('Error validating sign-in code for $email: $e');
      throw OperationFailedException('Failed to validate sign-in code: $e');
    }
  }

  @override
  Future<void> clearSignInCode(String email) async {
    try {
      // After successful validation, the code should be removed immediately.
      await _collection.deleteOne(where.eq('email', email));
      _log.info('Cleared sign-in code for $email');
    } catch (e) {
      _log.severe('Failed to clear sign-in code for $email: $e');
      throw OperationFailedException('Failed to clear sign-in code: $e');
    }
  }

  @override
  Future<void> cleanupExpiredCodes() async {
    // This is a no-op because the TTL index on the MongoDB collection
    // handles the cleanup automatically on the server side.
    _log.finer(
      'cleanupExpiredCodes() called, but no action is needed due to TTL index.',
    );
    return Future.value();
  }

  @override
  void dispose() {
    // This is a no-op because the underlying database connection is managed
    // by the injected MongoDbConnectionManager.
    _log.finer('dispose() called, no action needed.');
  }
}
