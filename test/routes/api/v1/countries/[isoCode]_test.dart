import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_countries_client/ht_countries_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// Import the route handler function directly.
import '../../../../../routes/api/v1/countries/[isoCode].dart' as route;

// --- Mocks ---
class _MockRequestContext extends Mock implements RequestContext {}

class _MockHttpRequest extends Mock
    implements Request {} // Use dart_frog Request

class _MockHtCountriesClient extends Mock implements HtCountriesClient {}
// --- End Mocks ---

void main() {
  late RequestContext context;
  late Request request;
  late HtCountriesClient mockClient;
  const isoCode = 'US'; // Example ISO code for tests
  final country = Country(
    isoCode: isoCode,
    name: 'United States',
    flagUrl: 'http://example.com/us.png',
    id: 'us_id_123',
  );

  setUp(() {
    context = _MockRequestContext();
    request = _MockHttpRequest();
    mockClient = _MockHtCountriesClient();

    // Provide the mock client instance
    when(() => context.read<HtCountriesClient>()).thenReturn(mockClient);
    // Link request mock to context mock
    when(() => context.request).thenReturn(request);

    // Register fallback values
    registerFallbackValue(HttpMethod.get);
    registerFallbackValue(Country(isoCode: 'XX', name: 'X', flagUrl: 'x'));
  });

  group('GET /api/v1/countries/{isoCode}', () {
    setUp(() {
      when(() => request.method).thenReturn(HttpMethod.get);
    });

    test('returns 200 OK with country data on success', () async {
      // Stub the client call
      when(() => mockClient.fetchCountry(isoCode))
          .thenAnswer((_) async => country);

      // Execute route handler
      final response = await route.onRequest(context, isoCode);

      // Assertions
      expect(response.statusCode, equals(HttpStatus.ok));
      expect(await response.json(), equals(country.toJson()));
      verify(() => mockClient.fetchCountry(isoCode)).called(1);
    });

    test('lets CountryNotFound bubble up (handled globally)', () async {
      const exception = CountryNotFound('Country $isoCode not found');
      when(() => mockClient.fetchCountry(isoCode)).thenThrow(exception);

      expect(
        () => route.onRequest(context, isoCode),
        throwsA(isA<CountryNotFound>()),
      );
      verify(() => mockClient.fetchCountry(isoCode)).called(1);
    });

    test('lets CountryFetchFailure bubble up (handled globally)', () async {
      const exception = CountryFetchFailure('Network error');
      when(() => mockClient.fetchCountry(isoCode)).thenThrow(exception);

      expect(
        () => route.onRequest(context, isoCode),
        throwsA(isA<CountryFetchFailure>()),
      );
      verify(() => mockClient.fetchCountry(isoCode)).called(1);
    });
  });

  group('PUT /api/v1/countries/{isoCode}', () {
    final updatedCountry = Country(
      isoCode: isoCode, // Must match path isoCode
      name: 'United States of America',
      flagUrl: 'http://example.com/us_new.png',
      id: country.id, // Usually keep the same ID or let backend handle
    );
    final requestBodyJson = updatedCountry.toJson();

    setUp(() {
      when(() => request.method).thenReturn(HttpMethod.put);
      // Stub request body parsing
      when(() => request.json()).thenAnswer((_) async => requestBodyJson);
      // Stub successful update call by default - overridden in failure tests
      when(() => mockClient.updateCountry(any())).thenAnswer((_) async {});
    });

    test('returns 200 OK on successful update', () async {
      final response = await route.onRequest(context, isoCode);

      expect(response.statusCode, equals(HttpStatus.ok));
      // Verify client was called with the correct updated country object
      verify(
        () => mockClient.updateCountry(
          any(
            that: isA<Country>()
                .having((c) => c.isoCode, 'isoCode', updatedCountry.isoCode)
                .having((c) => c.name, 'name', updatedCountry.name)
                .having((c) => c.flagUrl, 'flagUrl', updatedCountry.flagUrl)
                .having((c) => c.id, 'id', updatedCountry.id),
          ),
        ),
      ).called(1);
    });

    test('returns 400 Bad Request for invalid JSON body', () async {
      when(() => request.json()).thenThrow(const FormatException('Bad JSON'));

      final response = await route.onRequest(context, isoCode);

      expect(response.statusCode, equals(HttpStatus.badRequest));
      expect(
        await response.body(),
        equals('Invalid JSON format in request body.'),
      );
      verifyNever(() => mockClient.updateCountry(any()));
    });

    test('returns 400 Bad Request for invalid country data structure',
        () async {
      final invalidJson = {'name': 'Missing Iso Code'}; // Invalid structure
      when(() => request.json()).thenAnswer((_) async => invalidJson);

      final response = await route.onRequest(context, isoCode);

      expect(response.statusCode, equals(HttpStatus.badRequest));
      expect(
        await response.json(),
        containsPair('error', startsWith('Invalid country data:')),
      );
      verifyNever(() => mockClient.updateCountry(any()));
    });

    test('returns 400 Bad Request when path isoCode mismatches body isoCode',
        () async {
      final mismatchedBody = Map<String, dynamic>.from(requestBodyJson)
        ..['iso_code'] = 'XX'; // Different ISO code in body
      when(() => request.json()).thenAnswer((_) async => mismatchedBody);

      final response = await route.onRequest(context, isoCode); // Path is 'US'

      expect(response.statusCode, equals(HttpStatus.badRequest));
      expect(
        await response.json(),
        equals({
          'error': 'ISO code in request body ("XX") does not match ISO code '
              'in URL path ("US").',
        }),
      );
      verifyNever(() => mockClient.updateCountry(any()));
    });

    test('lets CountryNotFound bubble up (handled globally)', () async {
      const exception = CountryNotFound('Cannot update non-existent country');
      // Ensure the specific exception is thrown by the mock
      when(() => mockClient.updateCountry(any())).thenThrow(exception);

      // Expect the call to onRequest to throw the exception
      expect(
        () => route.onRequest(context, isoCode),
        throwsA(isA<CountryNotFound>()),
      );
    });

    test('lets CountryUpdateFailure bubble up (handled globally)', () async {
      const exception = CountryUpdateFailure('DB conflict during update');
      // Ensure the specific exception is thrown by the mock
      when(() => mockClient.updateCountry(any())).thenThrow(exception);

      // Expect the call to onRequest to throw the exception
      expect(
        () => route.onRequest(context, isoCode),
        throwsA(isA<CountryUpdateFailure>()),
      );
    });
  });

  group('DELETE /api/v1/countries/{isoCode}', () {
    setUp(() {
      when(() => request.method).thenReturn(HttpMethod.delete);
      // Stub successful delete call by default
      when(() => mockClient.deleteCountry(any())).thenAnswer((_) async {});
    });

    test('returns 204 No Content on successful deletion', () async {
      final response = await route.onRequest(context, isoCode);

      expect(response.statusCode, equals(HttpStatus.noContent));
      verify(() => mockClient.deleteCountry(isoCode)).called(1);
    });

    test('lets CountryNotFound bubble up (handled globally)', () async {
      const exception = CountryNotFound('Cannot delete non-existent country');
      when(() => mockClient.deleteCountry(isoCode)).thenThrow(exception);

      expect(
        () => route.onRequest(context, isoCode),
        throwsA(isA<CountryNotFound>()),
      );
      verify(() => mockClient.deleteCountry(isoCode)).called(1);
    });

    test('lets CountryDeleteFailure bubble up (handled globally)', () async {
      const exception = CountryDeleteFailure('Permission error');
      when(() => mockClient.deleteCountry(isoCode)).thenThrow(exception);

      expect(
        () => route.onRequest(context, isoCode),
        throwsA(isA<CountryDeleteFailure>()),
      );
      verify(() => mockClient.deleteCountry(isoCode)).called(1);
    });
  });

  test('returns 405 Method Not Allowed for unsupported methods', () async {
    // Test with POST, etc.
    when(() => request.method).thenReturn(HttpMethod.post);
    final responsePost = await route.onRequest(context, isoCode);
    expect(responsePost.statusCode, equals(HttpStatus.methodNotAllowed));

    verifyNever(() => mockClient.fetchCountry(any()));
    verifyNever(() => mockClient.updateCountry(any()));
    verifyNever(() => mockClient.deleteCountry(any()));
  });
}
