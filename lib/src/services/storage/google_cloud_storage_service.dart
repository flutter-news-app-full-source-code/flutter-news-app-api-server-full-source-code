import 'dart:async';
import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/storage/i_storage_service.dart';
import 'package:jose/jose.dart';
import 'package:logging/logging.dart';

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
  GoogleCloudStorageService({required Logger log}) : _log = log;

  final Logger _log;

  @override
  Future<String> generateUploadUrl({
    required String storagePath,
    required String contentType,
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
      _log.info(
        'Generating V2 signed URL for path: "$storagePath" in bucket: "$bucketName".',
      );

      final expiration = DateTime.now().toUtc().add(
        const Duration(minutes: 15),
      );
      final expirationTimestamp = (expiration.millisecondsSinceEpoch / 1000)
          .round();

      final stringToSign =
          'PUT\n\n$contentType\n$expirationTimestamp\n'
          '/$bucketName/$storagePath';

      final jwk = JsonWebKey.fromPem(
        privateKeyPem.replaceAll(r'\n', '\n'),
      );

      final signatureBytes = jwk.sign(
        utf8.encode(stringToSign),
        algorithm: 'RS256',
      );
      final signature = base64Encode(signatureBytes);

      final signedUrl =
          'https://storage.googleapis.com/$bucketName/$storagePath'
          '?GoogleAccessId=$serviceAccountEmail'
          '&Expires=$expirationTimestamp'
          '&Signature=${Uri.encodeComponent(signature)}';

      _log.info('Successfully generated signed URL.');
      return signedUrl;
    } catch (e, s) {
      _log.severe('Failed to generate signed URL', e, s);
      throw OperationFailedException('Failed to generate signed URL: $e');
    }
  }
}
