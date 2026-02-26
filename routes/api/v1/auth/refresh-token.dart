import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/response_helper.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('refresh_token_handler');

/// Handles POST requests to refresh an authentication token.
///
/// This endpoint requires an authenticated user. It takes the existing valid
/// token, fetches the user's latest language preference, and issues a new
/// token with the updated `lang` claim.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  return _handlePost(context);
}

Future<Response> _handlePost(RequestContext context) async {
  _log.info('Handling token refresh request.');
  final authService = context.read<AuthService>();
  final authenticatedUser = context.read<User>();

  final response = await authService.refreshAuthToken(authenticatedUser);

  _log.fine(
    'Successfully refreshed token for user: ${authenticatedUser.id}',
  );

  return ResponseHelper.success(
    context: context,
    data: response,
    toJsonT: (data) => data.toJson(),
  );
}

Handler middleware(Handler handler) {
  // This endpoint strictly requires an authenticated user.
  return handler.use(requireAuthentication());
}
