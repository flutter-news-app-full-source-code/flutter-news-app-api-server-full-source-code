import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/idempotency_record.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/idempotency_service.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockDataRepository<T> extends Mock implements DataRepository<T> {}

class MockLogger extends Mock implements Logger {}

void main() {
  late IdempotencyService service;
  late MockDataRepository<IdempotencyRecord> mockRepo;
  late MockLogger mockLogger;

  setUp(() {
    mockRepo = MockDataRepository<IdempotencyRecord>();
    mockLogger = MockLogger();
    service = IdempotencyService(repository: mockRepo, log: mockLogger);

    registerFallbackValue(
      IdempotencyRecord(id: 'fallback', createdAt: DateTime.now()),
    );
  });

  group('IdempotencyService', () {
    group('isEventProcessed', () {
      test('returns true if record exists', () async {
        when(() => mockRepo.read(id: any(named: 'id'))).thenAnswer(
          (_) async => IdempotencyRecord(id: '123', createdAt: DateTime.now()),
        );

        final result = await service.isEventProcessed('event-123');

        expect(result, isTrue);
      });

      test('returns false if record does not exist', () async {
        when(
          () => mockRepo.read(id: any(named: 'id')),
        ).thenThrow(const NotFoundException('Not found'));

        final result = await service.isEventProcessed('event-123');

        expect(result, isFalse);
      });

      test('generates different IDs for different scopes', () async {
        when(
          () => mockRepo.read(id: any(named: 'id')),
        ).thenThrow(const NotFoundException('Not found'));

        await service.isEventProcessed('event-123', scope: 'gcs');
        await service.isEventProcessed('event-123', scope: 's3');

        final capturedIds = verify(
          () => mockRepo.read(id: captureAny(named: 'id')),
        ).captured;

        expect(capturedIds.length, 2);
        expect(capturedIds[0], isNot(equals(capturedIds[1])));
      });
    });

    group('recordEvent', () {
      test('creates record with correct ID', () async {
        when(() => mockRepo.create(item: any(named: 'item'))).thenAnswer(
          (_) async => IdempotencyRecord(id: '123', createdAt: DateTime.now()),
        );

        await service.recordEvent('event-123', scope: 's3');

        verify(() => mockRepo.create(item: any(named: 'item'))).called(1);
      });

      test('rethrows exceptions', () async {
        when(
          () => mockRepo.create(item: any(named: 'item')),
        ).thenThrow(Exception('DB Error'));

        expect(
          () => service.recordEvent('event-123'),
          throwsException,
        );
      });
    });
  });
}
