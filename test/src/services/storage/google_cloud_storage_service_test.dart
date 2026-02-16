import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/google_auth_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/storage/google_cloud_storage_service.dart';
import 'package:http_client/http_client.dart';
import 'package:jose/jose.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockGoogleAuthService extends Mock implements IGoogleAuthService {}

class MockHttpClient extends Mock implements HttpClient {}

class MockJsonWebKey extends Mock implements JsonWebKey {}

void main() {
  group('GoogleCloudStorageService', () {
    late GoogleCloudStorageService storageService;
    late MockGoogleAuthService mockGoogleAuthService;
    late MockHttpClient mockHttpClient;

    const testBucketName = 'test-bucket';
    const testServiceAccountEmail = 'test@gserviceaccount.com';
    // A valid PEM private key for testing purposes.
    const testPrivateKey =
        '-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7V/D/4pddF0c5\n...\n-----END PRIVATE KEY-----';

    setUp(() {
      mockGoogleAuthService = MockGoogleAuthService();
      mockHttpClient = MockHttpClient();

      storageService = GoogleCloudStorageService(
        googleAuthService: mockGoogleAuthService,
        log: Logger('TestGcsService'),
        httpClient: mockHttpClient,
      );

      // Set environment variables for tests
      EnvironmentConfig.gcsBucketName = testBucketName;
      EnvironmentConfig.firebaseClientEmail = testServiceAccountEmail;
      EnvironmentConfig.firebasePrivateKey = testPrivateKey;

      when(
        () => mockGoogleAuthService.getAccessToken(scope: any(named: 'scope')),
      ).thenAnswer((_) async => 'test-access-token');
    });

    tearDown(() {
      EnvironmentConfig.gcsBucketName = null;
      EnvironmentConfig.firebaseClientEmail = null;
      EnvironmentConfig.firebasePrivateKey = null;
    });

    group('generateUploadUrl', () {
      test('successfully generates a V2 signed URL', () async {
        const storagePath = 'user-media/user-id/file.jpg';
        const contentType = 'image/jpeg';

        final url = await storageService.generateUploadUrl(
          storagePath: storagePath,
          contentType: contentType,
        );

        expect(
          url,
          startsWith(
            'https://storage.googleapis.com/$testBucketName/$storagePath',
          ),
        );
        expect(url, contains('GoogleAccessId=$testServiceAccountEmail'));
        expect(url, contains('Expires='));
        expect(url, contains('Signature='));
      });

      test(
        'throws OperationFailedException if bucket name is not configured',
        () {
          EnvironmentConfig.gcsBucketName = null;
          expect(
            () => storageService.generateUploadUrl(
              storagePath: 'path',
              contentType: 'type',
            ),
            throwsA(isA<OperationFailedException>()),
          );
        },
      );

      test(
        'throws OperationFailedException if service account email is not configured',
        () {
          EnvironmentConfig.firebaseClientEmail = null;
          expect(
            () => storageService.generateUploadUrl(
              storagePath: 'path',
              contentType: 'type',
            ),
            throwsA(isA<OperationFailedException>()),
          );
        },
      );

      test(
        'throws OperationFailedException if private key is not configured',
        () {
          EnvironmentConfig.firebasePrivateKey = null;
          expect(
            () => storageService.generateUploadUrl(
              storagePath: 'path',
              contentType: 'type',
            ),
            throwsA(isA<OperationFailedException>()),
          );
        },
      );
    });

    group('deleteObject', () {
      const storagePath = 'user-media/user-id/file.jpg';

      test('successfully deletes an object', () async {
        when(
          () => mockHttpClient.delete<void>(any()),
        ).thenAnswer((_) async => Future.value());

        await storageService.deleteObject(storagePath: storagePath);

        verify(
          () => mockHttpClient.delete<void>(
            '/storage/v1/b/$testBucketName/o/${Uri.encodeComponent(storagePath)}',
          ),
        ).called(1);
      });

      test(
        'throws OperationFailedException if bucket name is not configured',
        () {
          EnvironmentConfig.gcsBucketName = null;
          expect(
            () => storageService.deleteObject(storagePath: storagePath),
            throwsA(isA<OperationFailedException>()),
          );
        },
      );

      test(
        'throws OperationFailedException if auth service is not available',
        () {
          final serviceWithoutAuth = GoogleCloudStorageService(
            googleAuthService: null,
            log: Logger('TestGcsService'),
            httpClient: mockHttpClient,
          );

          expect(
            () => serviceWithoutAuth.deleteObject(storagePath: storagePath),
            throwsA(isA<OperationFailedException>()),
          );
        },
      );

      test('throws OperationFailedException if http client fails', () {
        when(
          () => mockHttpClient.delete<void>(any()),
        ).thenThrow(Exception('Network error'));

        expect(
          () => storageService.deleteObject(storagePath: storagePath),
          throwsA(isA<OperationFailedException>()),
        );
      });
    });
  });
}
