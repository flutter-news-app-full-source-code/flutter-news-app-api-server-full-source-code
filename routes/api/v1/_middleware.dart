import 'dart:io' show Platform; // To read environment variables

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/middlewares/authentication_middleware.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart' as shelf_cors;

/// Checks if the request's origin is allowed based on the environment.
///
/// In production (when `CORS_ALLOWED_ORIGIN` is set), it performs a strict
/// check against the specified origin.
/// In development, it dynamically allows any `localhost` or `127.0.0.1`
/// origin to support the Flutter web dev server's random ports.
bool _isOriginAllowed(String origin) {
  final allowedOriginEnv = Platform.environment['CORS_ALLOWED_ORIGIN'];

  if (allowedOriginEnv != null && allowedOriginEnv.isNotEmpty) {
    // Production: strict check against the environment variable.
    return origin == allowedOriginEnv;
  } else {
    // Development: dynamically allow any localhost origin.
    return origin.startsWith('http://localhost:') ||
        origin.startsWith('http://127.0.0.1:');
  }
}

Handler middleware(Handler handler) {
  // This middleware applies CORS and authentication to all routes under
  // `/api/v1/`. The order of `.use()` is important: the last one in the
  // chain runs first.
  return handler
      // 2. The authentication middleware runs after CORS, using the services
      //    provided from server.dart.
      .use(authenticationProvider())
      // 1. The CORS middleware runs first. It uses an `originChecker` to
      //    dynamically handle origins, which is the correct way to manage
      //    CORS in a standard middleware chain.
      .use(
        fromShelfMiddleware(
          shelf_cors.corsHeaders(
            originChecker: _isOriginAllowed,
            headers: {
              shelf_cors.ACCESS_CONTROL_ALLOW_CREDENTIALS: 'true',
              shelf_cors.ACCESS_CONTROL_ALLOW_METHODS:
                  'GET, POST, PUT, DELETE, OPTIONS',
              shelf_cors.ACCESS_CONTROL_ALLOW_HEADERS:
                  'Origin, Content-Type, Authorization, Accept',
              shelf_cors.ACCESS_CONTROL_MAX_AGE: '86400',
            },
          ),
        ),
      );
}
