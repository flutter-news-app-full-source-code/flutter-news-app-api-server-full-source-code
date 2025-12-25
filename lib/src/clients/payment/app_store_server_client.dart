import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/util/apple_jws_validator.dart';
import 'package:http_client/http_client.dart';
import 'package:jose/jose.dart';
import 'package:logging/logging.dart';

/// {@template app_store_server_client}
/// A client for interacting with the Apple App Store Server API.
///
/// This client handles the generation of the required JWT (JWS) for authentication
/// and provides methods to verify subscription status and transaction history.
/// {@endtemplate}
class AppStoreServerClient {
  /// {@macro app_store_server_client}
  AppStoreServerClient({
    required Logger log,
    HttpClient? httpClient,
  }) : _log = log,
       _httpClient =
           httpClient ??
           HttpClient(
             baseUrl: 'https://api.storekit.itunes.apple.com/inApps/v1',
             tokenProvider: () async =>
                 null, // Auth is handled per-request via JWT
           ) {
    _jwsValidator = AppleJwsValidator(log: log);
  }

  final Logger _log;
  final HttpClient _httpClient;
  late final AppleJwsValidator _jwsValidator;

  /// Generates a signed JWT (ES256) for App Store Server API authentication.
  String _generateJwt() {
    final issuerId = EnvironmentConfig.appleAppStoreIssuerId;
    final keyId = EnvironmentConfig.appleAppStoreKeyId;
    final privateKeyPem = EnvironmentConfig.appleAppStorePrivateKey;
    final bundleId = EnvironmentConfig.appleBundleId;

    if (issuerId == null ||
        keyId == null ||
        privateKeyPem == null ||
        bundleId == null) {
      throw const ServerException('Missing Apple App Store credentials.');
    }

    try {
      final key = JsonWebKey.fromPem(privateKeyPem, keyId: keyId);
      final now = DateTime.now();
      final claims = JsonWebTokenClaims.fromJson({
        'iss': issuerId,
        'iat': (now.millisecondsSinceEpoch / 1000).round(),
        'exp':
            (now.add(const Duration(minutes: 20)).millisecondsSinceEpoch / 1000)
                .round(),
        'aud': 'appstoreconnect-v1',
        'bid': bundleId,
      });

      final builder = JsonWebSignatureBuilder()
        ..jsonContent = claims.toJson()
        ..addRecipient(key, algorithm: 'ES256');

      return builder.build().toCompactSerialization();
    } catch (e, s) {
      _log.severe('Failed to generate Apple JWT', e, s);
      throw const ServerException(
        'Failed to generate Apple authentication token.',
      );
    }
  }

  /// Fetches all subscription statuses for a given original transaction ID.
  ///
  /// This endpoint returns the status of all subscriptions in the subscription
  /// group.
  Future<Map<String, dynamic>> getAllSubscriptionStatuses(
    String originalTransactionId,
  ) async {
    final token = _generateJwt();
    try {
      final response = await _httpClient.get<Map<String, dynamic>>(
        '/subscriptions/$originalTransactionId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      // Note: The response from this endpoint is NOT a JWS. It's a JSON object
      // containing lists of JWS strings (lastTransactions).
      // We return the raw map here, and the SubscriptionService will use
      // the JWS validator to decode the specific transaction fields.
      return response;
    } on HttpException catch (e) {
      if (e is NotFoundException) {
        _log.warning(
          'Apple subscription not found for transaction: $originalTransactionId',
        );
        rethrow;
      }
      _log.severe(
        'Apple API Error (getAllSubscriptionStatuses): ${e.message}',
      );
      rethrow;
    } catch (e, s) {
      _log.severe('Unexpected error calling Apple API', e, s);
      throw const ServerException(
        'Failed to verify subscription with Apple.',
      );
    }
  }

  /// Decodes a JWS string (e.g., signedTransactionInfo) using the validator.
  Map<String, dynamic> decodeJws(String jws) {
    return _jwsValidator.decode(jws);
  }
}
