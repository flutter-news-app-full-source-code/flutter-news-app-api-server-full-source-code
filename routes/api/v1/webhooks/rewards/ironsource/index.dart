// import 'dart:io';

// import 'package:core/core.dart';
// import 'package:dart_frog/dart_frog.dart';
// import 'package:flutter_news_app_api_server_full_source_code/src/services/reward/rewards_service.dart';
// import 'package:logging/logging.dart';

// final _log = Logger('IronSourceWebhookHandler');

// /// Handles GET requests for IronSource Server-Side Verification (SSV) callbacks.
// ///
// /// IronSource sends a GET request to this endpoint when a user completes a
// /// rewarded ad. The request contains query parameters with the transaction
// /// details and a cryptographic signature.
// ///
// /// This handler delegates the verification and reward granting logic to the
// /// [RewardsService].
// Future<Response> onRequest(RequestContext context) async {
//   _log.info('Received IronSource SSV request: ${context.request.uri}');
//   if (context.request.method != HttpMethod.get) {
//     return Response(statusCode: HttpStatus.methodNotAllowed);
//   }

//   final rewardsService = context.read<RewardsService>();

//   try {
//     await rewardsService.processCallback(
//       AdPlatformType.ironSource,
//       context.request.uri,
//     );
//     return Response(statusCode: HttpStatus.ok);
//   } on InvalidInputException catch (e) {
//     _log.warning('Invalid IronSource callback: ${e.message}');
//     return Response(statusCode: HttpStatus.badRequest, body: e.message);
//   } on ServerException catch (e) {
//     _log.severe('IronSource callback processing failed: ${e.message}', e);
//     return Response(statusCode: HttpStatus.internalServerError);
//   } catch (e, s) {
//     _log.severe('Unexpected error in IronSource webhook', e, s);
//     return Response(statusCode: HttpStatus.internalServerError);
//   }
// }
