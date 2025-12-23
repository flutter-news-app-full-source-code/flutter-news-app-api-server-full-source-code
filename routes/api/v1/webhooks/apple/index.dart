import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/payment/subscription_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('AppleWebhookHandler');

/// Handles Apple App Store Server Notifications (v2).
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final body = await context.request.json();
    final signedPayload = body['signedPayload'] as String?;

    if (signedPayload == null) {
      _log.warning('Received Apple webhook without signedPayload.');
      return Response(statusCode: HttpStatus.badRequest);
    }

    final subscriptionService = context.read<SubscriptionService>();
    await subscriptionService.handleAppleWebhook(signedPayload);

    return Response(statusCode: HttpStatus.ok);
  } catch (e, s) {
    _log.severe('Error processing Apple webhook', e, s);
    // Return 200 OK to Apple even on error to prevent retries of bad payloads
    return Response(statusCode: HttpStatus.ok);
  }
}
