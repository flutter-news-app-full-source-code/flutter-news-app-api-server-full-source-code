import 'dart:io' show Platform; // To read environment variables

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/middlewares/authentication_middleware.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart' as shelf_cors;

Handler middleware(Handler handler) {
  // This middleware applies providers and CORS handling to all routes
  // under /api/v1/.

  // --- CORS Configuration ---
  final allowedOriginEnv = Platform.environment['CORS_ALLOWED_ORIGIN'];
  String effectiveOrigin;

  if (allowedOriginEnv != null && allowedOriginEnv.isNotEmpty) {
    effectiveOrigin = allowedOriginEnv;
    print(
      '[CORS Middleware] Using Access-Control-Allow-Origin from '
      'CORS_ALLOWED_ORIGIN environment variable: "$effectiveOrigin"',
    );
  } else {
    // IMPORTANT: Default for local development ONLY if env var is not set.
    // You MUST set CORS_ALLOWED_ORIGIN in production for security.
    // This default allows credentials, so it cannot be '*'.
    // Adjust 'http://localhost:3000' if your local Flutter web dev server
    // typically runs on a different port.
    effectiveOrigin = 'http://localhost:39155';
    print('------------------------------------------------------------------');
    print('WARNING: CORS_ALLOWED_ORIGIN environment variable is NOT SET.');
    print(
      'Defaulting Access-Control-Allow-Origin to: "$effectiveOrigin" '
      'FOR DEVELOPMENT ONLY.',
    );
    print(
      'For production, you MUST set the CORS_ALLOWED_ORIGIN environment '
      "variable to your Flutter web application's specific domain.",
    );
    print('------------------------------------------------------------------');
  }

  final corsConfig = <String, String>{
    // Use the determined origin (from env var or development default)
    shelf_cors.ACCESS_CONTROL_ALLOW_ORIGIN: effectiveOrigin,
    // Crucial for authenticated APIs where the frontend sends credentials
    // (e.g., Authorization header with fetch({ credentials: 'include' }))
    shelf_cors.ACCESS_CONTROL_ALLOW_CREDENTIALS: 'true',
    // Define allowed HTTP methods
    shelf_cors.ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, DELETE, OPTIONS',
    // Define allowed headers from the client
    shelf_cors.ACCESS_CONTROL_ALLOW_HEADERS:
        'Origin, Content-Type, Authorization, Accept',
    // Optional: How long the results of a preflight request can be cached
    shelf_cors.ACCESS_CONTROL_MAX_AGE: '86400', // 24 hours
  };

  // Apply CORS middleware first.
  // `fromShelfMiddleware` adapts the Shelf-based CORS middleware for Dart Frog.
  var newHandler = handler.use(
    fromShelfMiddleware(shelf_cors.corsHeaders(headers: corsConfig)),
  );

  // Then apply the authenticationProvider.
  // ignore: join_return_with_assignment
  newHandler = newHandler.use(authenticationProvider());

  return newHandler;
}
