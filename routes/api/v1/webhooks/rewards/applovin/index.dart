import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/reward/rewards_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('AppLovinWebhookHandler');

/// Handles GET requests for AppLovin MAX S2S reward callbacks.
Future<Response> onRequest(RequestContext context) async {
  _log.info('Received AppLovin reward request: ${context.request.uri}');

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final rewardsService = context.read<RewardsService>();

  try {
    await rewardsService.processCallback(
      AdPlatformType.appLovin,
      context.request.uri,
    );
    return Response(statusCode: HttpStatus.ok);
  } on InvalidInputException catch (e) {
    _log.warning('Invalid AppLovin callback: ${e.message}');
    return Response(statusCode: HttpStatus.badRequest, body: e.message);
  } on ForbiddenException catch (e) {
    _log.warning('AppLovin callback forbidden: ${e.message}');
    return Response(statusCode: HttpStatus.forbidden, body: e.message);
  } on OperationFailedException catch (e) {
    _log.severe('AppLovin callback processing failed: ${e.message}');
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: e.message,
    );
  } catch (e, s) {
    _log.severe('Unexpected error in AppLovin webhook', e, s);
    return Response(statusCode: HttpStatus.internalServerError);
  }
}
