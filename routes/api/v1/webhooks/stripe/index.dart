import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/payment/subscription_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('StripeWebhookHandler');

/// Handles Stripe Webhook events.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final signature = context.request.headers['stripe-signature'];
    final payload = await context.request.body();

    if (signature == null) {
      _log.warning('Received Stripe webhook without signature.');
      return Response(statusCode: HttpStatus.badRequest);
    }

    final subscriptionService = context.read<SubscriptionService>();
    await subscriptionService.handleStripeWebhook(payload, signature);

    return Response(statusCode: HttpStatus.ok);
  } catch (e, s) {
    _log.severe('Error processing Stripe webhook', e, s);
    return Response(statusCode: HttpStatus.ok);
  }
}
