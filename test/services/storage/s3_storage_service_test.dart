import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/storage/s3_storage_service.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockLogger extends Mock implements Logger {}

void main() {
  late S3StorageService s3Service;
  late MockHttpClient mockHttpClient;
  late MockLogger mockLogger;

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockLogger = MockLogger();
    s3Service = S3StorageService(
      log: mockLogger,
      httpClient: mockHttpClient,
    );

    // Setup default environment for tests
    EnvironmentConfig.setOverride('AWS_ACCESS_KEY_ID', 'test_access_key');
    EnvironmentConfig.setOverride('AWS_SECRET_ACCESS_KEY', 'test_secret_key');
    EnvironmentConfig.setOverride('AWS_REGION', 'us-east-1');
    EnvironmentConfig.setOverride('AWS_BUCKET_NAME', 'test-bucket');
    EnvironmentConfig.setOverride('AWS_S3_ENDPOINT', null);
  });

  tearDown(() {
    // Clear overrides
    EnvironmentConfig.setOverride('AWS_ACCESS_KEY_ID', null);
    EnvironmentConfig.setOverride('AWS_SECRET_ACCESS_KEY', null);
    EnvironmentConfig.setOverride('AWS_REGION', null);
    EnvironmentConfig.setOverride('AWS_BUCKET_NAME', null);
    EnvironmentConfig.setOverride('AWS_S3_ENDPOINT', null);
  });

  group('S3StorageService', () {
    group('generateUploadUrl', () {
      test(
        'throws OperationFailedException if credentials are missing',
        () async {
          EnvironmentConfig.setOverride('AWS_ACCESS_KEY_ID', null);

          expect(
            () => s3Service.generateUploadUrl(
              storagePath: 'path/to/file.jpg',
              contentType: 'image/jpeg',
              maxSizeInBytes: 1024,
            ),
            throwsA(isA<OperationFailedException>()),
          );
        },
      );

      test('returns valid signed URL and fields', () async {
        final result = await s3Service.generateUploadUrl(
          storagePath: 'user/123/avatar.jpg',
          contentType: 'image/jpeg',
          maxSizeInBytes: 5 * 1024 * 1024,
        );

        expect(
          result['url'],
          'https://test-bucket.s3.us-east-1.amazonaws.com',
        );
        expect(result['fields'], isA<Map<String, dynamic>>());

        final fields = result['fields'] as Map<String, dynamic>;
        expect(fields['key'], 'user/123/avatar.jpg');
        expect(fields['Content-Type'], 'image/jpeg');
        expect(fields['x-amz-algorithm'], 'AWS4-HMAC-SHA256');
        expect(fields.containsKey('policy'), isTrue);
        expect(fields.containsKey('x-amz-signature'), isTrue);
        expect(fields.containsKey('x-amz-credential'), isTrue);
      });

      test('uses custom endpoint if provided', () async {
        EnvironmentConfig.setOverride(
          'AWS_S3_ENDPOINT',
          'https://minio.local',
        );

        final result = await s3Service.generateUploadUrl(
          storagePath: 'path.jpg',
          contentType: 'image/jpeg',
          maxSizeInBytes: 100,
        );

        expect(result['url'], 'https://minio.local');
      });
    });

    group('deleteObject', () {
      test(
        'throws OperationFailedException if credentials are missing',
        () async {
          EnvironmentConfig.setOverride('AWS_SECRET_ACCESS_KEY', null);

          expect(
            () => s3Service.deleteObject(storagePath: 'path/to/file.jpg'),
            throwsA(isA<OperationFailedException>()),
          );
        },
      );

      test('makes correct DELETE request with signature headers', () async {
        when(
          () => mockHttpClient.delete<void>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) async {});

        await s3Service.deleteObject(storagePath: 'user/123/file.jpg');

        verify(
          () => mockHttpClient.delete<void>(
            'https://test-bucket.s3.us-east-1.amazonaws.com/user/123/file.jpg',
            options: any(
              named: 'options',
              that: isA<Options>().having(
                (o) => o.headers,
                'headers',
                containsPair('Authorization', contains('AWS4-HMAC-SHA256')),
              ),
            ),
          ),
        ).called(1);
      });

      test('handles custom endpoint for deletion', () async {
        EnvironmentConfig.setOverride(
          'AWS_S3_ENDPOINT',
          'https://minio.local',
        );
        when(
          () => mockHttpClient.delete<void>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) async {});

        await s3Service.deleteObject(storagePath: 'file.jpg');

        verify(
          () => mockHttpClient.delete<void>(
            'https://minio.local/test-bucket/file.jpg',
            options: any(named: 'options'),
          ),
        ).called(1);
      });
    });
  });
}
