import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:verity_api/src/services/intelligence/intelligence_service.dart';
import 'package:verity_api/src/services/intelligence/strategies/single_enrichment_strategy.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await context.request.json() as Map<String, dynamic>;
  final partialHeadline = Headline.fromJson(body);

  final intelligenceService = context.read<IntelligenceService>();

  try {
    final enrichedHeadline = await intelligenceService.execute(
      strategy: SingleEnrichmentStrategy(),
      input: partialHeadline,
    );

    return Response.json(
      body: SuccessApiResponse(
        data: enrichedHeadline,
        metadata: ResponseMetadata(requestId: '', timestamp: DateTime.now()),
      ).toJson((h) => h.toJson()),
    );
  } on HttpException catch (e) {
    return Response.json(statusCode: 400, body: {'error': e.message});
  }
}
