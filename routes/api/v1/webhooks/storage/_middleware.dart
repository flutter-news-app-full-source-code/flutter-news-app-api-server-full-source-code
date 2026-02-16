// routes/api/v1/webhooks/storage/_middleware.dart
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/gcs_jwt_verification_middleware.dart';

Handler middleware(Handler handler) {
  // Secure the storage webhook endpoint by verifying the JWT from the
  // provider's notification service (e.g., Google Cloud Pub/Sub).
  return handler.use(gcsJwtVerificationMiddleware());
}
