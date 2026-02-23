import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/reward/rewards_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('AdMobWebhookHandler');

/// Handles GET requests for AdMob Server-Side Verification (SSV) callbacks.
///
/// AdMob sends a GET request to this endpoint when a user completes a rewarded
/// ad. The request contains query parameters with the transaction details and
/// a cryptographic signature.
///
/// This handler delegates the verification and reward granting logic to the
/// [RewardsService].
Future<Response> onRequest(RequestContext context) async {
  _log.info('Received AdMob SSV request: ${context.request.uri}');
  // AdMob SSV callbacks are GET requests.
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final rewardsService = context.read<RewardsService>();

  try {
    // Pass the full URI to the service to ensure access to the raw query string
    // for signature verification.
    await rewardsService.processCallback(
      AdPlatformType.admob,
      context.request.uri,
    );
    return Response(statusCode: HttpStatus.ok);
  } on InvalidInputException catch (e) {
    _log.warning('Invalid AdMob callback: ${e.message}');
    return Response(statusCode: HttpStatus.badRequest, body: e.message);
  } on ForbiddenException catch (e) {
    _log.warning('AdMob callback forbidden: ${e.message}');
    return Response(statusCode: HttpStatus.forbidden, body: e.message);
  } on OperationFailedException catch (e) {
    _log.severe('AdMob callback processing failed: ${e.message}');
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: e.message,
    );
  } catch (e, s) {
    _log.severe('Unexpected error in AdMob webhook', e, s);
    return Response(statusCode: HttpStatus.internalServerError);
  }
}
