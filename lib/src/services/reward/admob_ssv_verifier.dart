import 'dart:convert';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart' as asn1;
import 'package:core/core.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/reward/admob_reward_callback.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/reward/verified_reward_payload.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/reward/reward_verifier.dart';
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
class AdMobSsvVerifier implements RewardVerifier {
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
  /// "callback" is the parsed callback model.
  ///
  /// Throws [InvalidInputException] if the signature is invalid.
  /// Throws [OperationFailedException] if keys cannot be fetched or verification fails.
  @override
  Future<VerifiedRewardPayload> verify(Uri uri) async {
    final callback = AdMobRewardCallback.fromUri(uri);

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
    // AdMob sends a DER-encoded signature, but the 'jose' package (and most
    // JWA implementations) expects the IEEE P1363 format (R|S concatenated).
    final ieeeSignature = _convertDerToIeeeP1363(signatureBytes);
    final isValid = _verifySignature(
      publicKeyPem,
      contentBytes,
      ieeeSignature,
    );

    if (!isValid) {
      _log.warning('AdMob SSV signature verification failed.');
      throw const InvalidInputException('Invalid signature.');
    }

    _log.info('AdMob SSV signature verified successfully.');

    final rewardType = RewardType.values.firstWhere(
      (e) => e.name.toLowerCase() == callback.rewardItem.toLowerCase(),
      orElse: () => throw const BadRequestException('Unknown reward type.'),
    );

    return VerifiedRewardPayload(
      transactionId: callback.transactionId,
      userId: callback.userId,
      rewardType: rewardType,
    );
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
      throw const OperationFailedException(
        'Failed to fetch verification keys.',
      );
    }
  }

  /// Decodes a URL-safe Base64 string.
  Uint8List _decodeWebSafeBase64(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    final buffer = StringBuffer(normalized);
    while (normalized.length % 4 != 0) {
      buffer.write('=');
      normalized = buffer.toString();
    }
    return base64Decode(buffer.toString());
  }

  /// Converts a DER-encoded ECDSA signature (ASN.1) to IEEE P1363 format (R|S).
  ///
  /// AdMob provides signatures in DER format, but the `jose` package expects
  /// the raw R and S values concatenated (64 bytes total for P-256).
  Uint8List _convertDerToIeeeP1363(Uint8List derSignature) {
    try {
      final parser = asn1.ASN1Parser(derSignature);
      final sequence = parser.nextObject() as asn1.ASN1Sequence;

      final rValue = (sequence.elements[0] as asn1.ASN1Integer).contentBytes();
      final sValue = (sequence.elements[1] as asn1.ASN1Integer).contentBytes();

      // --- Pad to 32 bytes (for P-256) ---
      const elementLength = 32;
      final result = Uint8List(elementLength * 2);

      // Copy R (right-aligned)
      final rOffset = elementLength - rValue.length;
      if (rValue.length > elementLength) {
        // If longer than 32 bytes, skip leading bytes (usually sign padding 0x00)
        final diff = rValue.length - elementLength;
        result.setRange(0, elementLength, rValue.sublist(diff));
      } else {
        result.setRange(rOffset, elementLength, rValue);
      }

      // Copy S (right-aligned)
      final sOffset = (elementLength * 2) - sValue.length;
      if (sValue.length > elementLength) {
        // If longer than 32 bytes, skip leading bytes
        final diff = sValue.length - elementLength;
        result.setRange(
          elementLength,
          elementLength * 2,
          sValue.sublist(diff),
        );
      } else {
        result.setRange(sOffset, elementLength * 2, sValue);
      }

      return result;
    } catch (e) {
      _log.warning('Failed to parse DER signature: $e');
      throw const InvalidInputException(
        'Invalid DER signature format.',
      );
    }
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
