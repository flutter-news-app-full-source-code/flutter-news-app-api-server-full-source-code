import 'dart:io' show Platform; // To read environment variables

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/middlewares/authentication_middleware.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart' as shelf_cors;

// This middleware is implemented as a higher-order function that returns a
// handler. This approach is necessary to dynamically configure CORS headers
// based on the incoming request's 'Origin' header, which is only available
// within the request context.
Handler middleware(Handler handler) {
  return (RequestContext context) {
    // --- Dynamic CORS Configuration ---
    final allowedOriginEnv = Platform.environment['CORS_ALLOWED_ORIGIN'];
    final requestOrigin = context.request.headers['Origin'];
    String? effectiveOrigin;

    if (allowedOriginEnv != null && allowedOriginEnv.isNotEmpty) {
      // PRODUCTION: Use the strictly defined origin from the env variable.
      effectiveOrigin = allowedOriginEnv;
    } else {
      // DEVELOPMENT: Dynamically allow any localhost or 127.0.0.1 origin.
      // This is crucial because the Flutter web dev server runs on a random
      // port for each session.
      if (requestOrigin != null &&
          (requestOrigin.startsWith('http://localhost:') ||
              requestOrigin.startsWith('http://127.0.0.1:'))) {
        effectiveOrigin = requestOrigin;
      } else {
        // For other clients (like Postman) or if origin is missing in dev,
        // there's no specific origin to return. The CORS middleware will
        // simply not add the 'Access-Control-Allow-Origin' header if the
        // request's origin doesn't match, which is fine.
        effectiveOrigin = null;
      }
    }

    final corsConfig = <String, String>{
      // Crucial for authenticated APIs where the frontend sends credentials
      // (e.g., Authorization header with fetch({ credentials: 'include' }))
      shelf_cors.ACCESS_CONTROL_ALLOW_CREDENTIALS: 'true',
      // Define allowed HTTP methods
      shelf_cors.ACCESS_CONTROL_ALLOW_METHODS:
          'GET, POST, PUT, DELETE, OPTIONS',
      // Define allowed headers from the client
      shelf_cors.ACCESS_CONTROL_ALLOW_HEADERS:
          'Origin, Content-Type, Authorization, Accept',
      // Optional: How long the results of a preflight request can be cached
      shelf_cors.ACCESS_CONTROL_MAX_AGE: '86400', // 24 hours
    };

    if (effectiveOrigin != null) {
      corsConfig[shelf_cors.ACCESS_CONTROL_ALLOW_ORIGIN] = effectiveOrigin;
    }

    // The handler chain needs to be built and executed within this context.
    // Order: CORS -> Auth -> Route Handler
    final corsMiddleware = fromShelfMiddleware(
      shelf_cors.corsHeaders(headers: corsConfig),
    );
    final authMiddleware = authenticationProvider();

    // Chain the middlewares and the original handler together.
    // The request will flow through corsMiddleware, then authMiddleware,
    // then the original handler.
    final composedHandler = handler.use(authMiddleware).use(corsMiddleware);

    return composedHandler(context);
  };
}
