import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/idempotency_record.dart';
import 'package:logging/logging.dart';

/// {@template idempotency_service}
/// A service to ensure that critical operations (like payment processing)
/// are performed only once for a given event ID.
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

  /// Checks if an event with [id] has already been processed.
  ///
  /// Returns `true` if the event exists (is processed), `false` otherwise.
  Future<bool> isEventProcessed(String id) async {
    try {
      // We use read() which throws NotFoundException if not found.
      await _repository.read(id: id, userId: null);
      _log.info('Idempotency check: Event $id already processed.');
      return true;
    } on NotFoundException {
      return false;
    } catch (e) {
      _log.warning('Error checking idempotency for $id: $e');
      // Fail safe: If DB is down, assume not processed to allow retry,
      // or throw to prevent duplicate processing?
      // Throwing is safer for payments.
      throw const ServerException('Failed to check idempotency status.');
    }
  }

  /// Records an event [id] as processed.
  ///
  /// This should be called *after* the successful processing of the event.
  /// The record will be automatically deleted after the TTL expires.
  Future<void> recordEvent(String id) async {
    try {
      final record = IdempotencyRecord(
        id: id,
        createdAt: DateTime.now(),
      );
      await _repository.create(item: record, userId: null);
      _log.info('Recorded event $id as processed.');
    } catch (e) {
      _log.severe('Failed to record idempotency for $id: $e');
      // We don't rethrow here because the main operation succeeded.
      // However, this opens a small window for duplicate processing if
      // the client retries immediately.
    }
  }
}
