import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/app_store_server_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/apple_notification_payload.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/payment/subscription_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('AppleWebhookHandler');

/// Handles Apple App Store Server Notifications (v2).
///
/// This endpoint receives a JWS (JSON Web Signature) payload from Apple,
/// verifies it, decodes it into a strongly-typed [AppleNotificationPayload],
/// and passes it to the [SubscriptionService].
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

    // 1. Decode and Verify JWS
    // We use the AppStoreServerClient (which contains the validator) to
    // decode the payload.
    final appStoreClient = context.read<AppStoreServerClient>();
    final decodedMap = appStoreClient.decodeJws(signedPayload);

    // 2. Deserialize to Typed Model
    final payload = AppleNotificationPayload.fromJson(decodedMap);

    // 3. Process via Service
    final subscriptionService = context.read<SubscriptionService>();
    await subscriptionService.handleAppleNotification(payload);

    return Response(statusCode: HttpStatus.ok);
  } on FormatException catch (e) {
    _log.warning('Invalid Apple JWS format: $e');
    // Return 200 to stop Apple from retrying malformed requests
    return Response(statusCode: HttpStatus.ok);
  } catch (e, s) {
    _log.severe('Error processing Apple webhook', e, s);
    // Return 500 to trigger a retry from Apple if it's a transient server error
    return Response(statusCode: HttpStatus.internalServerError);
  }
}
