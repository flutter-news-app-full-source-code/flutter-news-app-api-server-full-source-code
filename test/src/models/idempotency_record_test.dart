import 'package:test/test.dart';
import 'package:verity_api/src/models/idempotency_record.dart';

void main() {
  group('IdempotencyRecord', () {
    final date = DateTime.parse('2023-01-01T12:00:00.000Z');
    final record = IdempotencyRecord(
      id: 'id-1',
      scope: 'test-scope',
      key: 'test-key',
      createdAt: date,
    );

    test('supports value equality', () {
      final record2 = IdempotencyRecord(
        id: 'id-1',
        scope: 'test-scope',
        key: 'test-key',
        createdAt: date,
      );
      expect(record, equals(record2));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 'id-1',
        'scope': 'test-scope',
        'key': 'test-key',
        'createdAt': '2023-01-01T12:00:00.000Z',
      };
      expect(IdempotencyRecord.fromJson(json), equals(record));
    });

    test('toJson serializes correctly', () {
      final json = record.toJson();
      expect(json['id'], 'id-1');
      expect(json['scope'], 'test-scope');
      expect(json['key'], 'test-key');
      expect(json['createdAt'], '2023-01-01T12:00:00.000Z');
    });
  });
}
