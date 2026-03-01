import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_backend_api/src/middlewares/authentication_middleware.dart';

Handler middleware(Handler handler) {
  // All routes in the /media group require an authenticated user.
  // The specific route handlers will perform their own permission checks.
  return handler.use(requireAuthentication());
}
