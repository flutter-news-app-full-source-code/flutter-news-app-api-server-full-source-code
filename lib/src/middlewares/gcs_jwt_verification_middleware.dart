// lib/src/middlewares/gcs_jwt_verification_middleware.dart
import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/util/gcs_jwt_verifier.dart';

/// Middleware to verify JWT tokens from a cloud provider's notification
/// service (e.g., Google Cloud Pub/Sub push subscriptions).
///
/// This ensures that webhook requests originate from the configured provider and are intended
/// for this service.
Middleware gcsJwtVerificationMiddleware({IGcsJwtVerifier? verifier}) {
  return (handler) {
    return (context) async {
      final jwtVerifier = verifier ?? context.read<IGcsJwtVerifier>();

      final authHeader = context.request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        throw const UnauthorizedException('Missing or invalid token.');
      }

      final token = authHeader.substring(7);
      final requestHost = context.request.uri.host;

      await jwtVerifier.verify(token, requestHost);

      return handler(context);
    };
  };
}
