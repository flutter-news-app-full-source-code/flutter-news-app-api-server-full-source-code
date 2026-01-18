import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/reward/admob_reward_callback.dart';
import 'package:http_client/http_client.dart';
import 'package:jose/jose.dart';
import 'package:logging/logging.dart';

/// {@template admob_ssv_verifier}
/// Verifies Server-Side Verification (SSV) callbacks from Google AdMob.
///
/// This class implements the cryptographic verification logic required by Google
/// to ensure that a reward callback genuinely originated from AdMob servers.
/// It fetches Google's public keys, parses the query parameters, and verifies
/// the ECDSA signature.
/// {@endtemplate}
class AdMobSsvVerifier {
  /// {@macro admob_ssv_verifier}
  AdMobSsvVerifier({
    required HttpClient httpClient,
    required Logger log,
  }) : _httpClient = httpClient,
       _log = log;

  final HttpClient _httpClient;
  final Logger _log;

  // The path to the keys JSON. The base URL (https://gstatic.com) is configured
  // in the HttpClient.
  static const String _keysPath = '/admob/reward/verifier-keys.json';

  // In-memory cache for public keys to avoid fetching on every request.
  // Structure: { keyId: PEM string }
  Map<String, String>? _cachedKeys;
  DateTime? _cacheExpiry;

  /// Verifies the signature of an incoming AdMob SSV callback.
  ///
  /// [callback] is the parsed callback model.
  ///
  /// Throws [InvalidInputException] if the signature is invalid.
  /// Throws [OperationFailedException] if keys cannot be fetched or verification fails.
  Future<void> verify(AdMobRewardCallback callback) async {
    // 1. Construct the content string to verify.
    // AdMob requires the query string excluding the signature and key_id parameters.
    // We use the raw query string from the URI to preserve order and encoding.
    final contentString = _reconstructContentString(callback.originalUri);
    final contentBytes = utf8.encode(contentString);
    final signatureBytes = _decodeWebSafeBase64(callback.signature);

    // 2. Fetch Public Keys
    final publicKeyPem = await _getPublicKey(callback.keyId);
    if (publicKeyPem == null) {
      _log.warning('Public key not found for key_id: ${callback.keyId}');
      throw const InvalidInputException('Invalid key_id.');
    }

    // 3. Verify Signature (ECDSA with SHA-256)
    final isValid = _verifySignature(
      publicKeyPem,
      contentBytes,
      signatureBytes,
    );

    if (!isValid) {
      _log.warning('AdMob SSV signature verification failed.');
      throw const InvalidInputException('Invalid signature.');
    }

    _log.info('AdMob SSV signature verified successfully.');
  }

  /// Reconstructs the query string excluding signature and key_id.
  String _reconstructContentString(Uri uri) {
    final query = uri.query;
    if (query.isEmpty) return '';

    final parts = query.split('&');
    final filteredParts = parts.where((part) {
      return !part.startsWith('signature=') && !part.startsWith('key_id=');
    });
    return filteredParts.join('&');
  }

  /// Fetches Google's public keys, using cache if available.
  Future<String?> _getPublicKey(String keyId) async {
    if (_cachedKeys != null &&
        _cacheExpiry != null &&
        DateTime.now().isBefore(_cacheExpiry!)) {
      return _cachedKeys![keyId];
    }

    try {
      _log.info('Fetching AdMob verifier keys...');
      final response = await _httpClient.get<Map<String, dynamic>>(_keysPath);
      final keys = response['keys'] as List<dynamic>;

      final newCache = <String, String>{};
      for (final keyData in keys) {
        final k = keyData as Map<String, dynamic>;
        final id = k['keyId'].toString();
        final pem = k['pem'].toString();
        newCache[id] = pem;
      }

      _cachedKeys = newCache;
      // Cache for 24 hours
      _cacheExpiry = DateTime.now().add(const Duration(hours: 24));

      return newCache[keyId];
    } catch (e, s) {
      _log.severe('Failed to fetch AdMob keys', e, s);
      throw const OperationFailedException('Failed to fetch verification keys.');
    }
  }

  /// Decodes a URL-safe Base64 string.
  Uint8List _decodeWebSafeBase64(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return base64Decode(normalized);
  }

  /// Verifies the ECDSA signature using the `jose` package.
  bool _verifySignature(
    String publicKeyPem,
    List<int> message,
    Uint8List signature,
  ) {
    try {
      // Parse the PEM string into a JsonWebKey.
      final key = JsonWebKey.fromPem(publicKeyPem);

      // Verify the signature using ES256 (ECDSA using P-256 and SHA-256).
      return key.verify(message, signature, algorithm: 'ES256');
    } catch (e) {
      _log.warning('Crypto verification error: $e');
      return false;
    }
  }
}
