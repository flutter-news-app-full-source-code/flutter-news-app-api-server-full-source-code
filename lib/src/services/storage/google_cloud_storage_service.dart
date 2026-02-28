import 'dart:async';
import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/google_auth_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/storage/i_storage_service.dart';
import 'package:jose/jose.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

/// {@template google_cloud_storage_service}
/// A concrete implementation of [IStorageService] that interacts with
/// Google Cloud Storage (GCS).
///
/// This service uses the existing Firebase service account credentials to
/// authenticate with Google Cloud and generate signed URLs for direct
/// client uploads. It leverages the `jose` package for cryptographic signing,
/// consistent with other verification services in the project.
/// {@endtemplate}
class GoogleCloudStorageService implements IStorageService {
  /// {@macro google_cloud_storage_service}
  GoogleCloudStorageService({
    required IGoogleAuthService? googleAuthService,
    required Logger log,
    @visibleForTesting HttpClient? httpClient,
  }) : _googleAuthService = googleAuthService,
       _log = log {
    _storageHttpClient =
        httpClient ??
        HttpClient(
          baseUrl: 'https://storage.googleapis.com',
          tokenProvider: () =>
              _googleAuthService?.getAccessToken(
                scope: 'https://www.googleapis.com/auth/devstorage.read_write',
              ) ??
              Future.value(null),
          logger: Logger('GcsHttpClient'),
        );
  }

  final Logger _log;
  final IGoogleAuthService? _googleAuthService;
  late final HttpClient _storageHttpClient;

  @override
  Future<Map<String, dynamic>> generateUploadUrl({
    required String storagePath,
    required String contentType,
    required int maxSizeInBytes,
  }) async {
    final bucketName = EnvironmentConfig.gcsBucketName;
    if (bucketName == null || bucketName.isEmpty) {
      _log.severe(
        'GCS_BUCKET_NAME is not configured in environment variables.',
      );
      throw const OperationFailedException(
        'Storage service is not configured.',
      );
    }

    final serviceAccountEmail = EnvironmentConfig.firebaseClientEmail;
    final privateKeyPem = EnvironmentConfig.firebasePrivateKey;

    if (serviceAccountEmail == null || privateKeyPem == null) {
      _log.severe(
        'Firebase service account credentials are not fully configured.',
      );
      throw const OperationFailedException(
        'Storage service is not configured.',
      );
    }

    try {
      _log.info('Generating V4 signed policy for path: "$storagePath".');

      final expiration = DateTime.now().toUtc().add(
        const Duration(minutes: 15),
      );

      final policy = {
        'conditions': [
          ['content-length-range', 0, maxSizeInBytes],
          {'bucket': bucketName},
          {'key': storagePath},
          {'Content-Type': contentType},
        ],
        'expiration': expiration.toIso8601String(),
      };

      final policyJson = jsonEncode(policy);
      final policyBase64 = base64Encode(utf8.encode(policyJson));

      final jwk = JsonWebKey.fromPem(
        privateKeyPem.replaceAll(r'\n', '\n').trim(),
      );

      final signatureBytes = jwk.sign(
        utf8.encode(policyBase64),
        algorithm: 'RS256',
      );
      final signature = base64Encode(signatureBytes);

      final fields = {
        'key': storagePath,
        'Content-Type': contentType,
        'GoogleAccessId': serviceAccountEmail,
        'policy': policyBase64,
        'signature': signature,
      };

      final url = 'https://storage.googleapis.com/$bucketName';

      _log.info('Successfully generated V4 signed policy.');
      return {'url': url, 'fields': fields};
    } catch (e, s) {
      _log.severe('Failed to generate signed URL', e, s);
      throw OperationFailedException('Failed to generate signed URL: $e');
    }
  }

  @override
  Future<void> deleteObject({required String storagePath}) async {
    final bucketName = EnvironmentConfig.gcsBucketName;
    if (bucketName == null || bucketName.isEmpty) {
      _log.severe(
        'GCS_BUCKET_NAME is not configured in environment variables.',
      );
      throw const OperationFailedException(
        'Storage service is not configured.',
      );
    }

    if (_googleAuthService == null) {
      _log.severe(
        'GoogleAuthService is not available. Cannot authenticate to GCS.',
      );
      throw const OperationFailedException(
        'Storage service is not configured.',
      );
    }

    try {
      _log.info('Deleting object at path: "$storagePath"');
      await _storageHttpClient.delete<void>(
        '/storage/v1/b/$bucketName/o/${Uri.encodeComponent(storagePath)}',
      );
      _log.info('Successfully deleted object at path: "$storagePath"');
    } on Exception catch (e, s) {
      _log.severe('Failed to delete object at path: "$storagePath"', e, s);
      throw OperationFailedException('Failed to delete object: $e');
    }
  }
}
