import 'package:core/core.dart';
import 'package:jose/jose.dart';
import 'package:logging/logging.dart';

/// An abstract interface for a service that verifies GCS Pub/Sub JWTs.
abstract class IGcsJwtVerifier {
  /// Verifies the given [token] against Google's public keys and checks
  /// standard claims like issuer, audience, and expiry.
  ///
  /// Throws an [UnauthorizedException] if verification fails for any reason.
  Future<void> verify(String token, String expectedAudience);
}

/// {@template gcs_jwt_verifier}
/// A concrete implementation of [IGcsJwtVerifier] that uses the `jose` package
/// to perform JWT verification.
/// {@endtemplate}
class GcsJwtVerifier implements IGcsJwtVerifier {
  /// {@macro gcs_jwt_verifier}
  GcsJwtVerifier({required Logger log}) : _log = log;

  final Logger _log;

  // The key store is created once and caches keys internally.
  final JsonWebKeyStore _keyStore = JsonWebKeyStore()
    ..addKeySetUrl(
      Uri.parse('https://www.googleapis.com/oauth2/v3/certs'),
    );

  @override
  Future<void> verify(String token, String expectedAudience) async {
    _log.info('Verifying GCS Pub/Sub JWT...');
    late final JsonWebSignature jws;
    try {
      jws = JsonWebSignature.fromCompactSerialization(token);
    } catch (e) {
      _log.warning('Failed to parse GCS JWT: $e');
      throw const UnauthorizedException('Invalid token format.');
    }

    if (!await jws.verify(_keyStore)) {
      _log.warning('GCS JWT signature verification failed.');
      throw const UnauthorizedException('Invalid signature.');
    }

    final claims = jws.unverifiedPayload.jsonContent as Map<String, dynamic>;
    final issuer = claims['iss'] as String?;
    if (issuer != 'https://accounts.google.com' &&
        issuer != 'accounts.google.com') {
      _log.warning('Invalid GCS JWT issuer: $issuer');
      throw const UnauthorizedException('Invalid token issuer.');
    }

    final audience = claims['aud'] as String?;
    if (audience == null || !audience.contains(expectedAudience)) {
      _log.warning(
        'Invalid GCS JWT audience: "$audience". Expected to contain "$expectedAudience".',
      );
      throw const UnauthorizedException('Invalid token audience.');
    }

    final expiry = claims['exp'] as int?;
    if (expiry == null ||
        DateTime.fromMillisecondsSinceEpoch(
          expiry * 1000,
        ).isBefore(DateTime.now())) {
      _log.warning('GCS JWT has expired.');
      throw const UnauthorizedException('Token has expired.');
    }
    _log.info('GCS Pub/Sub JWT successfully verified.');
  }
}
