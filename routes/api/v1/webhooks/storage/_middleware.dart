// routes/api/v1/webhooks/storage/_middleware.dart
import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/gcs_jwt_verification_middleware.dart';
import 'package:logging/logging.dart';

final _log = Logger('StorageWebhookMiddleware');

Handler middleware(Handler handler) {
  return (context) {
    final path = context.request.uri.path;

    // Apply GCS JWT verification ONLY for the GCS webhook route.
    if (path.endsWith('/gcs-notifications')) {
      return gcsJwtVerificationMiddleware()(handler)(context);
    }

    // For S3/SNS, we verify a shared secret in the query parameters.
    // This is a robust and standard way to secure webhooks when full
    // signature verification (which requires fetching certs) is too heavy.
    if (path.endsWith('/s3-notifications')) {
      final secret = context.request.uri.queryParameters['secret'];
      final configuredSecret = EnvironmentConfig.s3WebhookSecret;

      if (configuredSecret == null) {
        _log.severe('S3_WEBHOOK_SECRET is not configured. Rejecting request.');
        throw const ServerException('Webhook configuration error.');
      }

      if (secret != configuredSecret) {
        throw const UnauthorizedException('Invalid webhook secret.');
      }
    }

    return handler(context);
  };
}
