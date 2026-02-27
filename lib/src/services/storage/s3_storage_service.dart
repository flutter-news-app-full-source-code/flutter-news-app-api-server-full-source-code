import 'dart:convert';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/storage/i_storage_service.dart';
import 'package:logging/logging.dart';

/// {@template s3_storage_service}
/// A concrete implementation of [IStorageService] that interacts with AWS S3.
///
/// This service generates AWS Signature V4 Presigned POST URLs for secure,
/// direct-to-cloud file uploads.
/// {@endtemplate}
class S3StorageService implements IStorageService {
  /// {@macro s3_storage_service}
  S3StorageService({
    required Logger log,
    required HttpClient httpClient,
  }) : _log = log,
       _httpClient = httpClient;

  final Logger _log;
  final HttpClient _httpClient;

  @override
  Future<Map<String, dynamic>> generateUploadUrl({
    required String storagePath,
    required String contentType,
    required int maxSizeInBytes,
  }) async {
    final accessKey = EnvironmentConfig.awsAccessKeyId;
    final secretKey = EnvironmentConfig.awsSecretAccessKey;
    final region = EnvironmentConfig.awsRegion;
    final bucket = EnvironmentConfig.awsBucketName;

    if (accessKey == null ||
        secretKey == null ||
        region == null ||
        bucket == null) {
      _log.severe('AWS S3 credentials are not fully configured.');
      throw const OperationFailedException(
        'Storage service is not configured.',
      );
    }

    try {
      _log.info('Generating S3 Presigned POST for path: "$storagePath".');

      final now = DateTime.now().toUtc();
      final dateStamp =
          "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
      final xAmzDate =
          "${dateStamp}T${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}Z";
      final credentialScope = '$dateStamp/$region/s3/aws4_request';

      // Construct the policy
      final policy = {
        'expiration': now.add(const Duration(minutes: 15)).toIso8601String(),
        'conditions': [
          {'bucket': bucket},
          {'key': storagePath},
          {'Content-Type': contentType},
          ['content-length-range', 0, maxSizeInBytes],
          {'x-amz-credential': '$accessKey/$credentialScope'},
          {'x-amz-algorithm': 'AWS4-HMAC-SHA256'},
          {'x-amz-date': xAmzDate},
        ],
      };

      final policyJson = jsonEncode(policy);
      final policyBase64 = base64Encode(utf8.encode(policyJson));

      // Calculate Signature
      final signingKey = _getSignatureKey(secretKey, dateStamp, region, 's3');
      final signature = _hmacSha256Hex(signingKey, policyBase64);

      final fields = {
        'key': storagePath,
        'Content-Type': contentType,
        'x-amz-credential': '$accessKey/$credentialScope',
        'x-amz-algorithm': 'AWS4-HMAC-SHA256',
        'x-amz-date': xAmzDate,
        'policy': policyBase64,
        'x-amz-signature': signature,
      };

      // Determine the URL. Use custom endpoint if provided (e.g. MinIO),
      // otherwise standard AWS S3 URL.
      final url = 'https://$bucket.s3.$region.amazonaws.com';

      _log.info('Successfully generated S3 Presigned POST policy.');
      return {'url': url, 'fields': fields};
    } catch (e, s) {
      _log.severe('Failed to generate S3 signed URL', e, s);
      throw OperationFailedException('Failed to generate signed URL: $e');
    }
  }

  @override
  Future<void> deleteObject({required String storagePath}) async {
    final accessKey = EnvironmentConfig.awsAccessKeyId;
    final secretKey = EnvironmentConfig.awsSecretAccessKey;
    final region = EnvironmentConfig.awsRegion;
    final bucket = EnvironmentConfig.awsBucketName;

    if (accessKey == null ||
        secretKey == null ||
        region == null ||
        bucket == null) {
      throw const OperationFailedException('S3 credentials not configured.');
    }

    try {
      _log.info('Deleting object from S3: $storagePath');

      final now = DateTime.now().toUtc();
      final dateStamp =
          "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
      final amzDate =
          "${dateStamp}T${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}Z";

      // 1. Canonical Request
      const method = 'DELETE';
      final uri = '/$storagePath'; // Key is the path
      const queryString = '';
      // Host header is required for SigV4.
      // If using custom endpoint, parse it. Else construct standard AWS host.
      final host = '$bucket.s3.$region.amazonaws.com';

      final payloadHash = sha256
          .convert(utf8.encode(''))
          .toString(); // Empty payload
      final canonicalHeaders =
          'host:$host\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate\n';
      const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';
      final canonicalRequest =
          '$method\n$uri\n$queryString\n$canonicalHeaders\n$signedHeaders\n$payloadHash';

      // 2. String to Sign
      const algorithm = 'AWS4-HMAC-SHA256';
      final credentialScope = '$dateStamp/$region/s3/aws4_request';
      final stringToSign =
          '$algorithm\n$amzDate\n$credentialScope\n${sha256.convert(utf8.encode(canonicalRequest))}';

      // 3. Signature
      final signingKey = _getSignatureKey(secretKey, dateStamp, region, 's3');
      final signature = _hmacSha256Hex(signingKey, stringToSign);

      // 4. Authorization Header
      final authorization =
          '$algorithm Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

      // Execute Request.
      // We construct the full URL, which overrides any baseUrl configured in the HttpClient.
      final requestUrl =
          'https://$bucket.s3.$region.amazonaws.com/$storagePath';

      await _httpClient.delete<void>(
        requestUrl,
        options: Options(
          headers: {
            'Authorization': authorization,
            'x-amz-date': amzDate,
            'x-amz-content-sha256': payloadHash,
          },
        ),
      );
      _log.info('Successfully deleted S3 object: $storagePath');
    } catch (e, s) {
      _log.severe('Failed to delete S3 object: $storagePath', e, s);
      throw OperationFailedException('S3 Delete failed: $e');
    }
  }

  // --- AWS Signature V4 Helpers ---

  List<int> _hmacSha256(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(data)).bytes;
  }

  String _hmacSha256Hex(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(data)).toString();
  }

  List<int> _getSignatureKey(
    String key,
    String dateStamp,
    String regionName,
    String serviceName,
  ) {
    final kDate = _hmacSha256(utf8.encode('AWS4$key'), dateStamp);
    final kRegion = _hmacSha256(kDate, regionName);
    final kService = _hmacSha256(kRegion, serviceName);
    final kSigning = _hmacSha256(kService, 'aws4_request');
    return kSigning;
  }
}
