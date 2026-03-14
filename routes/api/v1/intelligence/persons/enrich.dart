import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:uuid/uuid.dart';
import 'package:veritai_api/src/services/services.dart';

const _uuid = Uuid();

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await context.request.json() as Map<String, dynamic>;
  body['type'] ??= 'person';
  final partial = Person.fromJson(body);
  final service = context.read<IntelligenceService>();

  try {
    final enriched = await service.enrichPerson(partial);
    return Response.json(
      body: SuccessApiResponse(
        data: enriched.toJson(),
        metadata: ResponseMetadata(
          requestId: _uuid.v4(),
          timestamp: DateTime.now(),
        ),
      ).toJson((d) => d),
    );
  } on HttpException catch (e) {
    return Response.json(statusCode: 400, body: {'error': e.message});
  }
}
