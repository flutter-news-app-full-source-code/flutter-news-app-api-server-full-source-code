import 'dart:convert';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/idempotency_record.dart';
import 'package:logging/logging.dart';

/// {@template idempotency_service}
/// A generic service for ensuring operations are performed exactly once.
///
/// It uses an [IdempotencyRecord] repository to track processed event IDs.
/// {@endtemplate}
class IdempotencyService {
  /// {@macro idempotency_service}
  const IdempotencyService({
    required DataRepository<IdempotencyRecord> repository,
    required Logger log,
  }) : _repository = repository,
       _log = log;

  final DataRepository<IdempotencyRecord> _repository;
  final Logger _log;

  /// Checks if an event with the given [eventId] has already been processed.
  ///
  /// Optionally accepts a [scope] to namespace the event ID (e.g., 'gcs', 's3').
  ///
  /// Returns `true` if the event exists, `false` otherwise.
  Future<bool> isEventProcessed(String eventId, {String? scope}) async {
    try {
      final dbId = _generateDeterministicId(eventId, scope);
      await _repository.read(id: dbId);
      return true;
    } on NotFoundException {
      return false;
    } catch (e, s) {
      _log.severe('Error checking idempotency for event $eventId', e, s);
      // Fail safe: If we can't check, assume not processed to avoid blocking,
      // OR assume processed to avoid duplication.
      // For payments/rewards, avoiding duplication is usually safer, but
      // blocking valid requests is bad.
      // We rethrow to let the caller decide or handle the error.
      rethrow;
    }
  }

  /// Records an event as processed.
  ///
  /// Optionally accepts a [scope] to namespace the event ID.
  ///
  /// Throws [ConflictException] if the event was recorded concurrently.
  Future<void> recordEvent(String eventId, {String? scope}) async {
    try {
      final dbId = _generateDeterministicId(eventId, scope);
      final record = IdempotencyRecord(
        id: dbId,
        createdAt: DateTime.now(),
      );
      await _repository.create(item: record);
    } catch (e, s) {
      _log.severe('Error recording idempotency for event $eventId', e, s);
      rethrow;
    }
  }

  /// Generates a deterministic 24-character hex string from an event ID.
  ///
  /// This is necessary to create a fixed-length, database-compatible string
  /// identifier from an arbitrary event ID for use as a document `_id`.
  String _generateDeterministicId(String eventId, String? scope) {
    final input = scope != null ? '$scope:$eventId' : eventId;
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    // SHA-256 produces 64 chars; take the first 24 for a valid ObjectId length.
    return digest.toString().substring(0, 24);
  }
}
