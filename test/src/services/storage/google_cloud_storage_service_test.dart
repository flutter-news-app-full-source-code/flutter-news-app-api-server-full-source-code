import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/google_auth_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/storage/google_cloud_storage_service.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockGoogleAuthService extends Mock implements IGoogleAuthService {}

class MockHttpClient extends Mock implements HttpClient {}

void main() {
  group('GoogleCloudStorageService', () {
    late GoogleCloudStorageService storageService;
    late MockGoogleAuthService mockGoogleAuthService;
    late MockHttpClient mockHttpClient;

    const testBucketName = 'test-bucket';
    const testServiceAccountEmail = 'test@gserviceaccount.com';

    setUp(() {
      mockGoogleAuthService = MockGoogleAuthService();
      mockHttpClient = MockHttpClient();

      // Set environment variables for tests
      EnvironmentConfig.setOverride('GCS_BUCKET_NAME', testBucketName);
      EnvironmentConfig.setOverride(
        'FIREBASE_CLIENT_EMAIL',
        testServiceAccountEmail,
      );
      // Use a real valid key here
      EnvironmentConfig.setOverride('FIREBASE_PRIVATE_KEY', _validRsaKey);

      storageService = GoogleCloudStorageService(
        googleAuthService: mockGoogleAuthService,
        log: Logger('TestGcsService'),
        httpClient: mockHttpClient,
      );

      when(
        () => mockGoogleAuthService.getAccessToken(scope: any(named: 'scope')),
      ).thenAnswer((_) async => 'test-access-token');
    });

    tearDown(() {
      EnvironmentConfig.setOverride('GCS_BUCKET_NAME', null);
      EnvironmentConfig.setOverride('FIREBASE_CLIENT_EMAIL', null);
      EnvironmentConfig.setOverride('FIREBASE_PRIVATE_KEY', null);
    });

    group('generateUploadUrl', () {
      test('successfully generates a V4 policy-signed POST document', () async {
        const storagePath = 'user-media/user-id/file.jpg';
        const contentType = 'image/jpeg';
        const maxSizeInBytes = 10 * 1024 * 1024;

        final result = await storageService.generateUploadUrl(
          storagePath: storagePath,
          contentType: contentType,
          maxSizeInBytes: maxSizeInBytes,
        );

        // Validate the structure for a V4 policy-signed POST request.
        expect(result, isA<Map<String, dynamic>>());
        expect(result['url'], 'https://storage.googleapis.com/$testBucketName');

        final fields = result['fields'] as Map<String, String>;
        expect(fields, isA<Map<String, String>>());
        expect(fields['key'], storagePath);
        expect(fields['Content-Type'], contentType);
        expect(fields['GoogleAccessId'], testServiceAccountEmail);
        expect(fields['policy'], isA<String>());
        expect(fields['signature'], isA<String>());

        // Decode the policy to verify its contents.
        final policy = fields['policy']!;
        final decodedPolicy = String.fromCharCodes(base64.decode(policy));
        expect(decodedPolicy, contains('"key":"$storagePath"'));
        expect(
          decodedPolicy,
          contains('["content-length-range",0,$maxSizeInBytes]'),
        );
      });

      test(
        'throws OperationFailedException if bucket name is not configured',
        () async {
          EnvironmentConfig.setOverride('GCS_BUCKET_NAME', null);
          expect(
            storageService.generateUploadUrl(
              storagePath: 'path',
              contentType: 'type',
              maxSizeInBytes: 1024,
            ),
            throwsA(isA<OperationFailedException>()),
          );
        },
      );

      test(
        'throws OperationFailedException if service account email is not configured',
        () async {
          EnvironmentConfig.setOverride('FIREBASE_CLIENT_EMAIL', null);
          expect(
            storageService.generateUploadUrl(
              storagePath: 'path',
              contentType: 'type',
              maxSizeInBytes: 1024,
            ),
            throwsA(isA<OperationFailedException>()),
          );
        },
      );

      test(
        'throws OperationFailedException if private key is not configured',
        () async {
          EnvironmentConfig.setOverride('FIREBASE_PRIVATE_KEY', '');
          expect(
            storageService.generateUploadUrl(
              storagePath: 'path',
              contentType: 'type',
              maxSizeInBytes: 1024,
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
        () async {
          EnvironmentConfig.setOverride('GCS_BUCKET_NAME', null);
          expect(
            storageService.deleteObject(storagePath: storagePath),
            throwsA(isA<OperationFailedException>()),
          );
        },
      );

      test(
        'throws OperationFailedException if auth service is not available',
        () async {
          final serviceWithoutAuth = GoogleCloudStorageService(
            googleAuthService: null,
            log: Logger('TestGcsService'),
            httpClient: mockHttpClient,
          );

          expect(
            serviceWithoutAuth.deleteObject(storagePath: storagePath),
            throwsA(isA<OperationFailedException>()),
          );
        },
      );

      test('throws OperationFailedException if http client fails', () async {
        when(
          () => mockHttpClient.delete<void>(any()),
        ).thenThrow(Exception('Network error'));

        expect(
          storageService.deleteObject(storagePath: storagePath),
          throwsA(isA<OperationFailedException>()),
        );
      });
    });
  });
}

// A valid RSA private key for testing.
const _validRsaKey =
    '-----BEGIN PRIVATE KEY-----\n'
    'MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCTthtJx/Ytv9TO\n'
    'Qht4agNko3eazBInodYVDn8Tu/y8vfJ+nZ8ZbcBVE1JtWIGv2VvalRWbU+kTv6kZ\n'
    'JVGdGLyuip+BpYJdabu3R/LBMnMGmBwdDjoIfQlZ05BnwKaJUTnA1Yr0RlKQtE4V\n'
    'm03xMZrAB/bfK05tmyy4Yu7cUi46E96eTdFLDLJiRJ415f5cay6J5FjuPQPFY8uZ\n'
    'NmM2mCd4fjAuc/4O6fRflYoNMbhzKYalNCrAK5pl83juLiDhJ6PPaUc5+rbb0Pic\n'
    '9Rap69TuFX71lvipoe6gWzaZumxtZ8CMX1Lf+MkljQXUPBy+xSK7RHvI1uYL0Vye\n'
    'OldZEdHVAgMBAAECggEAIBGu7f9UYs1dseQnW6bEktJssrZwkJsxxAOQMmQjdITW\n'
    'w4eMFbS+x5m40RWgnmGV8Chi9wSqO0fmuhdglzdaK5jcFYUt/wLoJtwfh7NgxsM6\n'
    'g1Jl5hbjc1Wb6fKpFXIFlGioUO19mn4S390GeIGZA+0Wu5AG6IQCmwubqUjMUX5P\n'
    'Pez91b3VK+bRdorFK1Ubi12SOWToHdlh9UMw6wzWraXf5TvOL74YY85NblDX9iaS\n'
    'sNJN0oYBd0EeNu9V8gDHE7EjqALYdFDXauvJlTOruh6o6XEBpvR8jYymj/5GuYGN\n'
    'edaye4c1f9/wUWtvBfzvTaOgdY78k+iKrimf/RWplwKBgQDPnsv/5mPOmzYBi/+H\n'
    '18fakpK+WzYfZXKk94ELfbSnTfnWYM/vGm+0X6zYkyIUSbppyTuHRa3Ifqbn5VHq\n'
    'BLL7dmwpaDQ3W60gVc+5M8OocD0r+leCEjFz+sTGMZFFLNGzYj8DdUn/5cPi2tCu\n'
    'qjQ5AVBvGk6/5VT0hkvHK/vatwKBgQC2IY2I+t9V1YFANHrZQbYorXx8e7T0wH8T\n'
    'YvVYnhNtaNvITLArI4DzHMPHPryBA7Q9tvPi1zLbMRVAIeLh7G26rpvqyEHu5T22\n'
    'lUOHWOW0ExK8G3I3l9LeVxWq/Iay+TmCdOzR9opjQCxzBgTAFux8wZL/pKe4/pGE\n'
    'yYIM5K7b0wKBgBZhvwoqMw49yzelePmS+HeGn40n1hDSZeaEzAOKHKSAknNa4m+b\n'
    'QPmH6uE6E01umUr4J5Ownkhj5uhO32LD+OuE26onEqH5HxPCTG9htjD9UIriJPbf\n'
    'sTcYjIf1Jfz4FO8qozJjPYP5qAFXp3F85b5TdvFTO7QSK/NkWtzwz+jHAoGBAIRB\n'
    'XSvJMQB9Z7wd389/3i0vvaQPmNnaJu0HAS52q5jZei+7MHpC79KaYrh+oBf3fp0K\n'
    'C5P/vRhaThoiAUUZkJztSp91CBvYL7Y0MbNJJJRc/U/HhmtEPoXiKwPdGFtCizZm\n'
    'fcoCA4ALC7wC9NQgUV5OmtY01O6LPVR1l5CRR0CtAoGAGNoHKbAFg3EstVFFYbsN\n'
    'zPdTQwCrSEl5/KzscDE0hpSaA/ul2l7zz4sz81RfJMnLRfMJDVd88WjijNhX/ke9\n'
    'JoR542FMr46c2WbSXyQ/K091BCRsF62+cth3RxBiqIHWsyTyBiY9NhhTtrl4Z4BY\n'
    'FrLY9oKANlCMvqvpZDpmi2M=\n'
    '-----END PRIVATE KEY-----';
