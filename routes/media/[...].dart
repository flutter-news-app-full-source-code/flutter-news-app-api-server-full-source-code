import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

/// A public, unauthenticated endpoint for serving locally stored media files.
Future<Response> onRequest(RequestContext context, String path) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final basePath = EnvironmentConfig.localStoragePath;
  if (basePath == null) {
    return Response(statusCode: HttpStatus.internalServerError);
  }

  // The path is everything after /media/
  final storagePath = path;

  // Security: Prevent path traversal attacks.
  // Normalize the path and check if it is still within the configured base path.
  final safePath = p.normalize(p.join(basePath, storagePath));
  if (!p.isWithin(basePath, safePath)) {
    return Response(statusCode: HttpStatus.forbidden);
  }

  final file = File(safePath);

  if (!file.existsSync()) {
    return Response(statusCode: HttpStatus.notFound);
  }

  final contentType = lookupMimeType(safePath) ?? 'application/octet-stream';

  return Response.bytes(
    body: await file.readAsBytes(),
    headers: {'Content-Type': contentType},
  );
}
