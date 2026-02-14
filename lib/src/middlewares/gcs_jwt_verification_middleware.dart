// lib/src/middlewares/gcs_jwt_verification_middleware.dart
import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:jose/jose.dart';
import 'package:logging/logging.dart';

final _log = Logger('GcsJwtVerificationMiddleware');

/// Middleware to verify JWT tokens from Google Cloud Pub/Sub push subscriptions.
///
/// This ensures that webhook requests originate from Google and are intended
/// for this service.
Middleware gcsJwtVerificationMiddleware() {
  return (handler) {
    return (context) async {
      _log.info('Verifying GCS Pub/Sub JWT...');

      final authHeader = context.request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        _log.warning('Missing or invalid Authorization header.');
        throw const UnauthorizedException('Missing or invalid token.');
      }

      final token = authHeader.substring(7);
      final jws = JsonWebSignature.fromCompactSerialization(token);

      // Fetch Google's public keys for verification.
      // The key store automatically caches keys.
      final keyStore = JsonWebKeyStore()
        ..addKeySetUrl(
          Uri.parse('https://www.googleapis.com/oauth2/v3/certs'),
        );

      // Verify the signature.
      if (!await jws.verify(keyStore)) {
        _log.warning('GCS JWT signature verification failed.');
        throw const UnauthorizedException('Invalid signature.');
      }
      _log.finer('GCS JWT signature is valid.');

      // Verify claims.
      final claims = jws.unverifiedPayload.jsonContent as Map<String, dynamic>;

      // 1. Verify issuer.
      final issuer = claims['iss'] as String?;
      if (issuer != 'https://accounts.google.com' &&
          issuer != 'accounts.google.com') {
        _log.warning('Invalid GCS JWT issuer: $issuer');
        throw const UnauthorizedException('Invalid token issuer.');
      }

      // 2. Verify audience.
      // The 'aud' claim should match the URL of your push endpoint.
      // We check against the host of the incoming request for flexibility.
      final audience = claims['aud'] as String?;
      final requestHost = context.request.uri.host;
      if (audience == null || !audience.contains(requestHost)) {
        _log.warning(
          'Invalid GCS JWT audience: "$audience". Expected to contain "$requestHost".',
        );
        throw const UnauthorizedException('Invalid token audience.');
      }

      // 3. Verify the token has not expired.
      final expiry = claims['exp'] as int?;
      if (expiry == null ||
          DateTime.fromMillisecondsSinceEpoch(expiry * 1000).isBefore(
            DateTime.now(),
          )) {
        _log.warning('GCS JWT has expired.');
        throw const UnauthorizedException('Token has expired.');
      }

      _log.info('GCS Pub/Sub JWT successfully verified.');
      return handler(context);
    };
  };
}
