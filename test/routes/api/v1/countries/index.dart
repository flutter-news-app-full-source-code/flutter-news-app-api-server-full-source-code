import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_countries_client/ht_countries_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// Import the route handler function directly.
import '../../../../../routes/api/v1/countries/index.dart' as route;

// --- Mocks ---
class _MockRequestContext extends Mock implements RequestContext {}

class _MockHttpRequest extends Mock implements Request {} // Use dart_frog Request

class _MockHtCountriesClient extends Mock implements HtCountriesClient {}
// --- End Mocks ---

void main() {
  late RequestContext context;
  late Request request;
  late HtCountriesClient mockClient;
  late Uri uri;

  // Helper to create a list of sample countries
  List<Country> createSampleCountries(int count) {
    return List.generate(
      count,
      (i) => Country(
        isoCode: 'C$i',
        name: 'Country $i',
        flagUrl: 'http://example.com/flag$i.png',
        id: 'id_$i', // Ensure unique IDs for pagination tests
      ),
    );
  }

  setUp(() {
    context = _MockRequestContext();
    request = _MockHttpRequest();
    mockClient = _MockHtCountriesClient();

    // Provide the mock client instance when context.read is called
    when(() => context.read<HtCountriesClient>()).thenReturn(mockClient);
    // Link the request mock to the context mock
    when(() => context.request).thenReturn(request);

    // Register fallback values for mocktail
    registerFallbackValue(Uri.parse('http://localhost/'));
    registerFallbackValue(HttpMethod.get); // Register HttpMethod enum
    registerFallbackValue(Country(isoCode: 'XX', name: 'X', flagUrl: 'x'));
  });

  group('GET /api/v1/countries', () {
    setUp(() {
      // Set request method for all GET tests in this group
      when(() => request.method).thenReturn(HttpMethod.get);
    });

    test('returns 200 OK with list of countries on success', () async {
      final countries = createSampleCountries(3);
      uri = Uri.parse('http://localhost/api/v1/countries?limit=10');
      when(() => request.uri).thenReturn(uri);
      // Stub the client call
      when(
        () => mockClient.fetchCountries(limit: 10, startAfterId: null),
      ).thenAnswer((_) async => countries);

      // Execute the route handler
      final response = await route.onRequest(context);

      // Assertions
      expect(response.statusCode, equals(HttpStatus.ok));
      expect(
        await response.json(),
        equals(countries.map((c) => c.toJson()).toList()),
      );
      verify(
        () => mockClient.fetchCountries(limit: 10, startAfterId: null),
      ).called(1);
    });

    test('uses default limit when limit parameter is missing', () async {
      final countries = createSampleCountries(2); // Less than default limit
      uri = Uri.parse('http://localhost/api/v1/countries'); // No limit param
      when(() => request.uri).thenReturn(uri);
      // Stub with default limit (20)
      when(
        () => mockClient.fetchCountries(limit: 20, startAfterId: null),
      ).thenAnswer((_) async => countries);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      verify(
        () => mockClient.fetchCountries(limit: 20, startAfterId: null),
      ).called(1);
    });

     test('uses max limit when limit parameter exceeds max', () async {
      final countries = createSampleCountries(5);
      // Limit is 150, should be clamped to 100 (defined in route)
      uri = Uri.parse('http://localhost/api/v1/countries?limit=150');
      when(() => request.uri).thenReturn(uri);
      // Stub with max limit (100)
      when(
        () => mockClient.fetchCountries(limit: 100, startAfterId: null),
      ).thenAnswer((_) async => countries);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      verify(
        () => mockClient.fetchCountries(limit: 100, startAfterId: null),
      ).called(1);
    });

    test('passes startAfterId to client when provided', () async {
      final countries = createSampleCountries(1);
      const startId = 'id_5';
      uri = Uri.parse(
        'http://localhost/api/v1/countries?limit=5&startAfterId=$startId',
      );
      when(() => request.uri).thenReturn(uri);
      when(
        () => mockClient.fetchCountries(limit: 5, startAfterId: startId),
      ).thenAnswer((_) async => countries);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      verify(
        () => mockClient.fetchCountries(limit: 5, startAfterId: startId),
      ).called(1);
    });

    test('returns 400 Bad Request for invalid limit parameter', () async {
      uri = Uri.parse('http://localhost/api/v1/countries?limit=abc');
      when(() => request.uri).thenReturn(uri);
      // No client call expected

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
      expect(
        await response.body(), // Check raw body for non-JSON error
        equals('Invalid query parameter: "limit" must be an integer.'),
      );
      verifyNever(
        () => mockClient.fetchCountries(limit: any(named: 'limit'), startAfterId: any(named: 'startAfterId')),
      );
    });

    // Add test for client throwing CountryFetchFailure (handled by global handler)
    test('lets CountryFetchFailure bubble up (handled globally)', () async {
      uri = Uri.parse('http://localhost/api/v1/countries?limit=10');
      when(() => request.uri).thenReturn(uri);
      final exception = CountryFetchFailure('DB error');
      when(
        () => mockClient.fetchCountries(limit: 10, startAfterId: null),
      ).thenThrow(exception);

      // Expect the specific exception to be thrown, letting the global handler catch it
      expect(
        () => route.onRequest(context),
        throwsA(isA<CountryFetchFailure>()),
      );

      verify(
        () => mockClient.fetchCountries(limit: 10, startAfterId: null),
      ).called(1);
    });
  });

  group('POST /api/v1/countries', () {
    final newCountry = Country(
      isoCode: 'FR',
      name: 'France',
      flagUrl: 'http://example.com/fr.png',
    );
    final newCountryJson = newCountry.toJson();
    // Remove 'id' as it's generated by client/constructor usually
    final requestJson = Map<String, dynamic>.from(newCountryJson)..remove('id');


    setUp(() {
      // Set request method for all POST tests in this group
      when(() => request.method).thenReturn(HttpMethod.post);
      // Stub the request body parsing
      when(() => request.json()).thenAnswer(
        (_) async => requestJson,
      );
      // Stub the client create method for success case by default
      when(() => mockClient.createCountry(any())).thenAnswer((_) async {});
    });

    test('returns 201 Created on successful creation', () async {
      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.created));
      // Verify client was called with a Country object matching the input JSON
      verify(
        () => mockClient.createCountry(
          any(
            that: isA<Country>()
                .having((c) => c.isoCode, 'isoCode', newCountry.isoCode)
                .having((c) => c.name, 'name', newCountry.name)
                .having((c) => c.flagUrl, 'flagUrl', newCountry.flagUrl),
          ),
        ),
      ).called(1);
    });

    test('returns 400 Bad Request for invalid JSON body', () async {
      // Override request.json stub to throw format exception
      when(() => request.json()).thenThrow(
        FormatException('Unexpected character'),
      );

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
      expect(
        await response.body(), // Check raw body
        equals('Invalid JSON format in request body.'),
      );
      verifyNever(() => mockClient.createCountry(any()));
    });

     test('returns 400 Bad Request for invalid country data structure', () async {
       // Provide JSON missing a required field
       final invalidJson = {'iso_code': 'DE', 'flag_url': '...'}; // Missing name
       when(() => request.json()).thenAnswer((_) async => invalidJson);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
      expect(
        await response.json(),
        containsPair('error', startsWith('Invalid country data:')),
      );
      verifyNever(() => mockClient.createCountry(any()));
    });

    // Add test for client throwing CountryCreateFailure (handled by global handler)
     test('lets CountryCreateFailure bubble up (handled globally)', () async {
      final exception = CountryCreateFailure('Duplicate entry');
      when(() => mockClient.createCountry(any())).thenThrow(exception);

      // Expect the specific exception to be thrown
      expect(
        () => route.onRequest(context),
        throwsA(isA<CountryCreateFailure>()),
      );

      verify(() => mockClient.createCountry(any())).called(1);
    });
  });

   test('returns 405 Method Not Allowed for unsupported methods', () async {
    // Test with PUT, DELETE etc.
    when(() => request.method).thenReturn(HttpMethod.put);
    final responsePut = await route.onRequest(context);
    expect(responsePut.statusCode, equals(HttpStatus.methodNotAllowed));

    when(() => request.method).thenReturn(HttpMethod.delete);
    final responseDelete = await route.onRequest(context);
    expect(responseDelete.statusCode, equals(HttpStatus.methodNotAllowed));

     verifyNever(() => mockClient.fetchCountries(limit: any(named: 'limit'), startAfterId: any(named: 'startAfterId')));
     verifyNever(() => mockClient.createCountry(any()));
  });
}
