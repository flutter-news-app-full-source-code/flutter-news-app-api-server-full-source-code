import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/google_subscription_notification.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/payment/subscription_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('GoogleWebhookHandler');

/// Handles Google Play Real-Time Developer Notifications (RTDN).
/// These are delivered via Google Cloud Pub/Sub.
///
/// The endpoint expects a Pub/Sub message format. It decodes the base64
/// data field, deserializes it into a [GoogleSubscriptionNotification],
/// and passes it to the [SubscriptionService].
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

    final dataBase64 = message['data'] as String?;
    if (dataBase64 == null) {
      _log.warning('Received Google webhook without data field.');
      return Response(statusCode: HttpStatus.badRequest);
    }

    // 1. Decode Base64 Data
    final decodedString = utf8.decode(base64.decode(dataBase64));
    final json = jsonDecode(decodedString) as Map<String, dynamic>;

    // 2. Deserialize to Typed Model
    final payload = GoogleSubscriptionNotification.fromJson(json);

    // 3. Process via Service
    final subscriptionService = context.read<SubscriptionService>();
    await subscriptionService.handleGoogleNotification(payload);

    return Response(statusCode: HttpStatus.ok);
  } on FormatException catch (e) {
    _log.warning('Invalid Google webhook format: $e');
    // Return 200 to acknowledge receipt and stop retries for bad data
    return Response(statusCode: HttpStatus.ok);
  } catch (e, s) {
    _log.severe('Error processing Google webhook', e, s);
    // Return 500 to trigger retry for transient errors
    return Response(statusCode: HttpStatus.internalServerError);
  }
}
