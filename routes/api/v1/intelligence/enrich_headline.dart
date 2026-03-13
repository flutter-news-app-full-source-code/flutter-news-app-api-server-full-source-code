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
  final partialHeadline = Headline.fromJson(body);

  final intelligenceService = context.read<IntelligenceService>();

  try {
    final result = await intelligenceService.execute(
      strategy: SingleEnrichmentStrategy(),
      input: partialHeadline,
    );

    // 1. Resolve Persons (creates them if they don't exist)
    final identityService = context.read<IdentityResolutionService>();

    final resolutionResult = await identityService.resolvePersons(
      result.extractedPersons,
    );
    final persons = resolutionResult.persons;

    // 2. Resolve Topic (by slug)
    var topic = partialHeadline.topic;
    if (result.topicSlug != null) {
      final topicRepo = context.read<DataRepository<Topic>>();
      // We assume slugs match the english name for now, or use a proper slug field if added.
      // For this implementation, we search by name.
      final topics = await topicRepo.readAll(
        filter: {'name.en': result.topicSlug},
        pagination: const PaginationOptions(limit: 1),
      );
      if (topics.items.isNotEmpty) {
        topic = topics.items.first;
      }
    }

    // 3. Resolve Countries (by ISO code)
    final countries = <Country>[];
    if (result.extractedCountryCodes.isNotEmpty) {
      final countryRepo = context.read<DataRepository<Country>>();
      final countryResponse = await countryRepo.readAll(
        filter: {
          'isoCode': {r'$in': result.extractedCountryCodes},
        },
      );
      countries.addAll(countryResponse.items);
    }

    final enrichedHeadline = partialHeadline.copyWith(
      title: {...partialHeadline.title, ...result.translations},
      mentionedPersons: persons,
      mentionedCountries: countries,
      topic: topic,
    );

    return Response.json(
      body: SuccessApiResponse(
        data: enrichedHeadline,
        metadata: ResponseMetadata(
          requestId: _uuid.v4(),
          timestamp: DateTime.now(),
        ),
      ).toJson((h) => h.toJson()),
    );
  } on HttpException catch (e) {
    return Response.json(statusCode: 400, body: {'error': e.message});
  }
}
