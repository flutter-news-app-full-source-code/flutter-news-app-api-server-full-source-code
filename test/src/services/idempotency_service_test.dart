import 'dart:convert';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/idempotency_record.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/idempotency_service.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockDataRepository<T> extends Mock implements DataRepository<T> {}

class MockLogger extends Mock implements Logger {}

void main() {
  group('IdempotencyService', () {
    late DataRepository<IdempotencyRecord> mockRepository;
    late Logger mockLogger;
    late IdempotencyService service;
    const eventId = 'test-event-id';

    // Calculate the expected hashed ID (SHA-256 of 'test-event-id' truncated to 24 chars)
    final expectedDbId = sha256
        .convert(utf8.encode(eventId))
        .toString()
        .substring(0, 24);

    setUpAll(() {
      registerFallbackValue(
        IdempotencyRecord(id: 'fallback', createdAt: DateTime.now()),
      );
    });

    setUp(() {
      mockRepository = MockDataRepository<IdempotencyRecord>();
      mockLogger = MockLogger();
      service = IdempotencyService(
        repository: mockRepository,
        log: mockLogger,
      );
    });

    group('isEventProcessed', () {
      test('returns true when repository finds the record', () async {
        when(
          () => mockRepository.read(id: expectedDbId, userId: null),
        ).thenAnswer(
          (_) async => IdempotencyRecord(
            id: expectedDbId,
            createdAt: DateTime.now(),
          ),
        );

        final result = await service.isEventProcessed(eventId);

        expect(result, isTrue);
        verify(
          () => mockRepository.read(id: expectedDbId, userId: null),
        ).called(1);
      });

      test('returns false when repository throws NotFoundException', () async {
        when(
          () => mockRepository.read(id: expectedDbId, userId: null),
        ).thenThrow(const NotFoundException('Not found'));

        final result = await service.isEventProcessed(eventId);

        expect(result, isFalse);
      });

      test('rethrows ServerException on other repository errors', () async {
        when(
          () => mockRepository.read(id: expectedDbId, userId: null),
        ).thenThrow(const ServerException('DB down'));

        expect(
          () => service.isEventProcessed(eventId),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('recordEvent', () {
      test('calls repository.create with correct IdempotencyRecord', () async {
        when(() => mockRepository.create(item: any(named: 'item'))).thenAnswer(
          (_) async => IdempotencyRecord(
            id: expectedDbId,
            createdAt: DateTime.now(),
          ),
        );

        await service.recordEvent(eventId);

        final captured =
            verify(
                  () => mockRepository.create(item: captureAny(named: 'item')),
                ).captured.first
                as IdempotencyRecord;

        expect(captured.id, expectedDbId);
        expect(captured.createdAt, isA<DateTime>());
      });
    });
  });
}
