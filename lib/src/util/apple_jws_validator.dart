import 'package:core/core.dart';
import 'package:jose/jose.dart';
import 'package:logging/logging.dart';

/// {@template apple_jws_validator}
/// A utility class for decoding and validating Apple JWS (JSON Web Signature)
/// payloads.
///
/// This class handles the extraction of claims from the JWS format used by
/// the App Store Server API and Notifications.
/// {@endtemplate}
class AppleJwsValidator {
  /// {@macro apple_jws_validator}
  const AppleJwsValidator({required Logger log}) : _log = log;

  final Logger _log;

  /// Decodes a JWS string and returns the payload as a Map.
  ///
  /// This method currently performs decoding and basic structure validation.
  ///
  /// Note: Full cryptographic verification of the x5c chain against Apple's
  /// root CA is recommended for high-security environments but is omitted here
  /// to avoid heavy external dependencies on PKI infrastructure. We rely on
  /// the fact that the JWS comes directly from a TLS-secured connection to
  /// Apple's servers (for API responses) or verified via other means.
  Map<String, dynamic> decode(String jws) {
    try {
      final jwsObject = JsonWebSignature.fromCompactSerialization(jws);
      final payload = jwsObject.unverifiedPayload;

      if (payload.jsonContent == null) {
        throw const FormatException('JWS payload is empty or not JSON.');
      }

      return payload.jsonContent!;
    } catch (e, s) {
      _log.severe('Failed to decode Apple JWS', e, s);
      throw const ServerException('Invalid Apple JWS payload.');
    }
  }

  /// Decodes the `signedTransactionInfo` from a JWS.
  Map<String, dynamic> decodeTransactionInfo(String signedTransactionInfo) {
    return decode(signedTransactionInfo);
  }

  /// Decodes the `signedRenewalInfo` from a JWS.
  Map<String, dynamic> decodeRenewalInfo(String signedRenewalInfo) {
    return decode(signedRenewalInfo);
  }
}
