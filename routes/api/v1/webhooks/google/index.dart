import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/payment/subscription_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('GoogleWebhookHandler');

/// Handles Google Play Real-Time Developer Notifications (RTDN).
/// These are delivered via Google Cloud Pub/Sub.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final body = await context.request.json();
    // Google Pub/Sub message format: { "message": { "data": "base64...", ... } }
    final message = body['message'] as Map<String, dynamic>?;

    if (message == null) {
      _log.warning('Received Google webhook without message field.');
      return Response(statusCode: HttpStatus.badRequest);
    }

    final subscriptionService = context.read<SubscriptionService>();
    await subscriptionService.handleGoogleWebhook(message);

    return Response(statusCode: HttpStatus.ok);
  } catch (e, s) {
    _log.severe('Error processing Google webhook', e, s);
    return Response(statusCode: HttpStatus.ok);
  }
}
