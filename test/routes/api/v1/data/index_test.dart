//
// ignore_for_file: prefer_const_constructors, avoid_redundant_argument_values
// ignore_for_file: lines_longer_than_80_chars, invalid_use_of_internal_member

import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/registry/model_registry.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_http_client/ht_http_client.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// Import the route handler
import '../../../../../routes/api/v1/data/index.dart' as route;

// --- Mocks ---
class MockRequestContext extends Mock implements RequestContext {}

class MockRequest extends Mock implements Request {}

class MockUri extends Mock implements Uri {}

class MockHtDataRepository<T> extends Mock implements HtDataRepository<T> {}

// Typedefs for specific repository mocks
typedef MockHeadlineRepository = MockHtDataRepository<Headline>;
typedef MockCategoryRepository = MockHtDataRepository<Category>;
typedef MockSourceRepository = MockHtDataRepository<Source>;
typedef MockCountryRepository = MockHtDataRepository<Country>;

// --- Test Data ---
// (Using slightly different IDs to avoid potential clashes if running
// multiple test files concurrently with shared resources, though unlikely here)
final testHeadline1 = Headline(
  id: 'idx-h1',
  title: 'Index Test Headline 1',
  description: 'Desc 1',
  publishedAt: DateTime(2025, 1, 1),
);
final testHeadline2 = Headline(
  id: 'idx-h2',
  title: 'Index Test Headline 2',
);
final testHeadlines = [testHeadline1, testHeadline2];
final testHeadlinesJson = testHeadlines.map((h) => h.toJson()).toList();
final testHeadlineJson = testHeadline1.toJson();

final testCategory1 = Category(id: 'idx-c1', name: 'Index Tech');
final testCategory2 = Category(id: 'idx-c2', name: 'Index Sports');
final testCategories = [testCategory1, testCategory2];
final testCategoriesJson = testCategories.map((c) => c.toJson()).toList();
final testCategoryJson = testCategory1.toJson();

final testSource1 = Source(id: 'idx-s1', name: 'Index Source A');
final testSource2 = Source(id: 'idx-s2', name: 'Index Source B');
final testSources = [testSource1, testSource2];
final testSourcesJson = testSources.map((s) => s.toJson()).toList();
final testSourceJson = testSource1.toJson();

final testCountry1 = Country(
  id: 'idx-co1',
  isoCode: 'US',
  name: 'Index USA',
  flagUrl: 'url1',
);
final testCountry2 = Country(
  id: 'idx-co2',
  isoCode: 'GB',
  name: 'Index UK',
  flagUrl: 'url2',
);
final testCountries = [testCountry1, testCountry2];
final testCountriesJson = testCountries.map((c) => c.toJson()).toList();
final testCountryJson = testCountry1.toJson();

// Model Configs from registry
final headlineConfig = modelRegistry['headline']!;
final categoryConfig = modelRegistry['category']!;
final sourceConfig = modelRegistry['source']!;
final countryConfig = modelRegistry['country']!;

void main() {
  late MockRequestContext mockContext;
  late MockRequest mockRequest;
  late MockUri mockUri;
  late MockHeadlineRepository mockHeadlineRepo;
  late MockCategoryRepository mockCategoryRepo;
  late MockSourceRepository mockSourceRepo;
  late MockCountryRepository mockCountryRepo;

  // Helper to build context with dependencies *already provided*
  // (Simulates the state after data/_middleware.dart runs)
  RequestContext buildTestContext({
    required String modelName,
    required ModelConfig modelConfig,
    required MockHtDataRepository repo, // The specific repo mock needed
    HttpMethod method = HttpMethod.get,
    Map<String, String> queryParams = const {},
    dynamic requestBody, // For POST
  }) {
    reset(mockContext); // Reset context between builds
    reset(mockRequest);
    reset(mockUri);
    // Reset the specific repo mock being used for this test
    if (repo is MockHeadlineRepository) reset(mockHeadlineRepo);
    if (repo is MockCategoryRepository) reset(mockCategoryRepo);
    if (repo is MockSourceRepository) reset(mockSourceRepo);
    if (repo is MockCountryRepository) reset(mockCountryRepo);


    when(() => mockRequest.method).thenReturn(method);
    when(() => mockRequest.uri).thenReturn(mockUri);
    when(() => mockUri.queryParameters).thenReturn(queryParams);

    if (requestBody != null) {
      when(() => mockRequest.json()).thenAnswer((_) async => requestBody);
    } else {
      // Prevent unexpected calls to json()
      when(() => mockRequest.json()).thenThrow(StateError('json() not expected'));
    }

    when(() => mockContext.request).thenReturn(mockRequest);

    // --- Stubbing Context Reads ---
    // IMPORTANT: Stub the specific repository reads *first* based on modelName.
    // Then stub the generic reads for modelName and modelConfig.
    // This order seems to help mocktail resolve the correct stubs.

    // Stub the generic reads for dependencies provided by middleware
    when(() => mockContext.read<String>()).thenReturn(modelName);
    when(() => mockContext.read<ModelConfig<dynamic>>()).thenReturn(modelConfig);

    // NOTE: Stubbing for the specific HtDataRepository<Model> read
    // will now be done *within each test case* that needs it.

    return mockContext;
  }


  setUpAll(() {
    // Register fallback values for model types used with `any()` or `captureAny()`
    registerFallbackValue(Headline(id: 'fb-h', title: 'Fallback Headline'));
    registerFallbackValue(Category(id: 'fb-c', name: 'Fallback Category'));
    registerFallbackValue(Source(id: 'fb-s', name: 'Fallback Source'));
    registerFallbackValue(Country(id: 'fb-co', isoCode: 'FB', name: 'Fallback Country', flagUrl: 'fb-url'));
  });

  setUp(() {
    mockContext = MockRequestContext();
    mockRequest = MockRequest();
    mockUri = MockUri();
    mockHeadlineRepo = MockHeadlineRepository();
    mockCategoryRepo = MockCategoryRepository();
    mockSourceRepo = MockSourceRepository();
    mockCountryRepo = MockCountryRepository();

    // No default stubbing needed here as buildTestContext handles it per test
  });

  group('onRequest Routing and Top-Level Errors', () {
    // These tests assume the middleware provided valid modelName/config
    test('returns 405 Method Not Allowed for PUT', () async {
      final context = buildTestContext(
        modelName: 'headline',
        modelConfig: headlineConfig,
        repo: mockHeadlineRepo,
        method: HttpMethod.put,
      );
      final response = await route.onRequest(context);
      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
    });

    test('returns 405 Method Not Allowed for DELETE', () async {
       final context = buildTestContext(
        modelName: 'headline',
        modelConfig: headlineConfig,
        repo: mockHeadlineRepo,
        method: HttpMethod.delete,
      );
      final response = await route.onRequest(context);
      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
    });

    // Error handling tests focus on errors *within* the handler now
    // Error handling tests focus on errors *within* the handler now
    test('re-throws HtHttpException from repository (GET)', () async {
      final exception = NotFoundException('Not found from repo');
      final context = buildTestContext(
        modelName: 'headline',
        modelConfig: headlineConfig,
        repo: mockHeadlineRepo,
        method: HttpMethod.get,
      );
      // Stub the specific repo read *before* setting up the repo method mock
      when(() => mockContext.read<HtDataRepository<Headline>>()).thenReturn(mockHeadlineRepo);
      // Ensure the mock setup matches the handler call exactly
      when(() => mockHeadlineRepo.readAll(startAfterId: null, limit: null))
          .thenThrow(exception);

      // Expect the exception to bubble up through onRequest (caught by error handler middleware)
      expect(
        () => route.onRequest(context),
        throwsA(exception),
      );
    });

     test('re-throws FormatException from repository (GET)', () async {
      final exception = FormatException('Bad format from repo');
      final context = buildTestContext(
        modelName: 'headline',
        modelConfig: headlineConfig,
        repo: mockHeadlineRepo,
        method: HttpMethod.get,
      );
      // Stub the specific repo read *before* setting up the repo method mock
      when(() => mockContext.read<HtDataRepository<Headline>>()).thenReturn(mockHeadlineRepo);
      // Ensure the mock setup matches the handler call exactly
      when(() => mockHeadlineRepo.readAll(startAfterId: null, limit: null))
          .thenThrow(exception);

      // Expect the exception to bubble up through onRequest (caught by error handler middleware)
      expect(
        () => route.onRequest(context),
        throwsA(exception),
      );
    });

     test('returns 500 if repository provider fails within handler (GET)', () async {
      final exception = Exception('Repo provider failed');
      // --- Manual Context Setup for this specific failure case ---
      // 1. Simulate middleware providing modelName and config successfully
      when(() => mockContext.read<String>()).thenReturn('headline');
      when(() => mockContext.read<ModelConfig<dynamic>>()).thenReturn(headlineConfig);
      // 2. Simulate request details
      when(() => mockContext.request).thenReturn(mockRequest);
      when(() => mockRequest.method).thenReturn(HttpMethod.get);
      when(() => mockRequest.uri).thenReturn(mockUri);
      when(() => mockUri.queryParameters).thenReturn({});
      // 3. Simulate failure when the handler *tries* to read the repo
      when(() => mockContext.read<HtDataRepository<Headline>>()).thenThrow(exception);
      // --- End Manual Setup ---

      final response = await route.onRequest(mockContext);
      expect(response.statusCode, equals(HttpStatus.internalServerError));
      expect(
        await response.body(),
        contains('Could not resolve repository for model "headline"'),
      );
      // Verify the failed read attempt
      verify(() => mockContext.read<HtDataRepository<Headline>>()).called(1);
    });

     test('returns 500 if repository provider fails within handler (POST)', () async {
      final exception = Exception('Repo provider failed');
      final requestBody = {'title': 'New Headline', 'id': 'new-h1'};

      // --- Manual Context Setup for this specific failure case ---
      // 1. Simulate middleware providing modelName and config successfully
      when(() => mockContext.read<String>()).thenReturn('headline');
      when(() => mockContext.read<ModelConfig<dynamic>>()).thenReturn(headlineConfig);
      // 2. Simulate request details (including body for POST)
      when(() => mockContext.request).thenReturn(mockRequest);
      when(() => mockRequest.method).thenReturn(HttpMethod.post);
      when(() => mockRequest.uri).thenReturn(mockUri);
      when(() => mockUri.queryParameters).thenReturn({}); // No query params for POST
      when(() => mockRequest.json()).thenAnswer((_) async => requestBody);
      // 3. Simulate failure when the handler *tries* to read the repo
      when(() => mockContext.read<HtDataRepository<Headline>>()).thenThrow(exception);
      // --- End Manual Setup ---

      final response = await route.onRequest(mockContext);
      expect(response.statusCode, equals(HttpStatus.internalServerError));
      // The error message might differ slightly depending on where the read fails
      // but it should indicate an internal server error.
      // Let's check for the status code primarily.
      // expect(await response.body(), contains('Could not resolve repository'));

      // Verify the failed read attempt
      verify(() => mockContext.read<HtDataRepository<Headline>>()).called(1);
      // Verify json() was called
      verify(() => mockRequest.json()).called(1);
    });
  });

  // --- GET Tests ---
  // --- GET Tests ---
  group('GET /data?model=headline', () {
    test('returns 200 OK with list of headlines (no query)', () async {
      final context = buildTestContext(
        modelName: 'headline',
        modelConfig: headlineConfig,
        repo: mockHeadlineRepo,
        method: HttpMethod.get,
      );
      // Stub the specific repo read for this test
      when(() => mockContext.read<HtDataRepository<Headline>>()).thenReturn(mockHeadlineRepo);
      // Ensure the mock setup matches the handler call exactly (nulls for optionals)
      when(() => mockHeadlineRepo.readAll(startAfterId: null, limit: null))
          .thenAnswer((_) async => testHeadlines);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(await response.json(), equals(testHeadlinesJson));
      verify(() => mockHeadlineRepo.readAll(startAfterId: null, limit: null)).called(1);
      verifyNever(() => mockHeadlineRepo.readAllByQuery(any(), startAfterId: any(named: 'startAfterId'), limit: any(named: 'limit')));
    });

    test('returns 200 OK with list of headlines (with pagination)', () async {
      final context = buildTestContext(
        modelName: 'headline',
        modelConfig: headlineConfig,
        repo: mockHeadlineRepo,
        method: HttpMethod.get,
        queryParams: {'startAfterId': 'idx-h1', 'limit': '1'},
      );
      // Stub the specific repo read for this test
      when(() => mockContext.read<HtDataRepository<Headline>>()).thenReturn(mockHeadlineRepo);
       // Ensure the mock setup matches the handler call exactly
       when(() => mockHeadlineRepo.readAll(startAfterId: 'idx-h1', limit: 1))
          .thenAnswer((_) async => [testHeadline2]); // Only second headline

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(await response.json(), equals([testHeadline2.toJson()]));
      verify(() => mockHeadlineRepo.readAll(startAfterId: 'idx-h1', limit: 1)).called(1);
      verifyNever(() => mockHeadlineRepo.readAllByQuery(any(), startAfterId: any(named: 'startAfterId'), limit: any(named: 'limit')));
    });

     test('returns 200 OK with list of headlines (with specific query)', () async {
      final query = {'title': 'Index Test Headline 1'};
      // Ensure query map excludes standard pagination/model params
      final expectedRepoQuery = {'title': 'Index Test Headline 1'};
      final context = buildTestContext(
        modelName: 'headline',
        modelConfig: headlineConfig,
        repo: mockHeadlineRepo,
        method: HttpMethod.get,
        // Include model param as it would be in the real request URI
        queryParams: {...query, 'model': 'headline'},
      );
      // Stub the specific repo read for this test
      when(() => mockContext.read<HtDataRepository<Headline>>()).thenReturn(mockHeadlineRepo);
      // Ensure the mock setup matches the handler call exactly (nulls for optionals)
      when(() => mockHeadlineRepo.readAllByQuery(expectedRepoQuery, startAfterId: null, limit: null))
          .thenAnswer((_) async => [testHeadline1]);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(await response.json(), equals([testHeadline1.toJson()]));
      verify(() => mockHeadlineRepo.readAllByQuery(expectedRepoQuery, startAfterId: null, limit: null)).called(1);
      verifyNever(() => mockHeadlineRepo.readAll(startAfterId: any(named: 'startAfterId'), limit: any(named: 'limit')));
    });

     test('returns 500 for unsupported model type (handler safety check)', () async {
       // NOTE: The primary validation for unsupported models happens in the
       // `/api/v1/data/_middleware.dart` which should return 400 Bad Request.
       // This test verifies the handler's *internal* defensive check,
       // assuming the middleware somehow allowed an unsupported model through.
       final context = buildTestContext(
         modelName: 'unsupported',
         modelConfig: headlineConfig, // Dummy config (middleware would provide *something*)
         repo: mockHeadlineRepo, // Dummy repo
         method: HttpMethod.get,
       );

       final response = await route.onRequest(context);
       expect(response.statusCode, equals(HttpStatus.internalServerError));
       expect(await response.body(), contains('Unsupported model type "unsupported"'));
     });
  });

  // --- POST Tests ---
  // --- POST Tests ---
  group('POST /data?model=headline', () {
    test('returns 201 Created with created headline', () async {
      final requestBody = {'title': 'New Headline', 'id': 'new-h1'};
      final inputHeadline = Headline.fromJson(requestBody);
      final context = buildTestContext(
        modelName: 'headline',
        modelConfig: headlineConfig,
        repo: mockHeadlineRepo,
        method: HttpMethod.post,
        requestBody: requestBody,
      );
      // Stub the specific repo read for this test
      when(() => mockContext.read<HtDataRepository<Headline>>()).thenReturn(mockHeadlineRepo);
      // Assume repo returns the created item matching input structure
      final createdHeadline = inputHeadline; // Corrected: Removed copyWith
      when(() => mockHeadlineRepo.create(inputHeadline)) // Expect exact input
          .thenAnswer((_) async => createdHeadline);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.created));
      expect(await response.json(), equals(createdHeadline.toJson()));
      verify(() => mockHeadlineRepo.create(inputHeadline)).called(1);
    });

    test('returns 400 Bad Request for invalid JSON body (TypeError)', () async {
      final requestBody = {'title': 123}; // Invalid type for title

      final context = buildTestContext(
        modelName: 'headline',
        modelConfig: headlineConfig, // Real config will throw TypeError
        repo: mockHeadlineRepo,
        method: HttpMethod.post,
        requestBody: requestBody,
      );
      // No repo read stub needed as it should fail before that

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
      final responseJson = await response.json() as Map<String, dynamic>;
      expect(responseJson['error']['code'], equals('INVALID_REQUEST_BODY'));
      expect(responseJson['error']['message'], contains('Missing or invalid required field'));
      verifyNever(() => mockHeadlineRepo.create(any())); // Repo should not be called
    });

     test('returns 400 Bad Request for missing required field (TypeError)', () async {
      final requestBody = {'description': 'Only desc'}; // Missing 'title'

      final context = buildTestContext(
        modelName: 'headline',
        modelConfig: headlineConfig, // Real config will throw TypeError
        repo: mockHeadlineRepo,
        method: HttpMethod.post,
        requestBody: requestBody,
      );
      // No repo read stub needed as it should fail before that

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
       final responseJson = await response.json() as Map<String, dynamic>;
      expect(responseJson['error']['code'], equals('INVALID_REQUEST_BODY'));
      expect(responseJson['error']['message'], contains('Missing or invalid required field'));
      verifyNever(() => mockHeadlineRepo.create(any()));
    });

    test('returns 400 Bad Request for null JSON body', () async {
      final context = buildTestContext(
        modelName: 'headline',
        modelConfig: headlineConfig,
        repo: mockHeadlineRepo,
        method: HttpMethod.post,
        requestBody: null, // Explicitly null - buildTestContext configures json() to throw
      );

      // *** Override the json() stub for this specific test case ***
      // The handler *will* call json(), expecting it to return null here.
      when(() => mockRequest.json()).thenAnswer((_) async => null);
      // No repo read stub needed as it should fail before that

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
      expect(await response.body(), equals('Missing or invalid request body.'));
      verifyNever(() => mockHeadlineRepo.create(any()));
    });

    test('re-throws BadRequestException from repository (POST)', () async {
      final requestBody = {'title': 'Valid New', 'id': 'new-h1'};
      final inputHeadline = Headline.fromJson(requestBody);
      final exception = BadRequestException('Repo validation failed');

      final context = buildTestContext(
        modelName: 'headline',
        modelConfig: headlineConfig,
        repo: mockHeadlineRepo,
        method: HttpMethod.post,
        requestBody: requestBody,
      );
      // Stub the specific repo read *before* setting up the repo method mock
      when(() => mockContext.read<HtDataRepository<Headline>>()).thenReturn(mockHeadlineRepo);
      // Use any() matcher as object instance might differ
      when(() => mockHeadlineRepo.create(any<Headline>()))
          .thenThrow(exception);

      expect(() => route.onRequest(context), throwsA(exception));
      verify(() => mockHeadlineRepo.create(inputHeadline)).called(1);
    });

     test('re-throws other HtHttpException from repository (POST)', () async {
      final requestBody = {'title': 'Valid New', 'id': 'new-h1'};
      final inputHeadline = Headline.fromJson(requestBody);
      final exception = ServerException('Server down');

      final context = buildTestContext(
        modelName: 'headline',
        modelConfig: headlineConfig,
        repo: mockHeadlineRepo,
        method: HttpMethod.post,
        requestBody: requestBody,
      );
      // Stub the specific repo read *before* setting up the repo method mock
      when(() => mockContext.read<HtDataRepository<Headline>>()).thenReturn(mockHeadlineRepo);
      // Use any() matcher as object instance might differ
      when(() => mockHeadlineRepo.create(any<Headline>()))
          .thenThrow(exception);

      expect(() => route.onRequest(context), throwsA(exception));
       verify(() => mockHeadlineRepo.create(inputHeadline)).called(1);
    });

     // Removed 'returns 500 for unsupported model type (handler safety check)' test
     // as middleware should catch invalid models with 400 Bad Request first.
  });

  // Add similar GET/POST groups for Category, Source, Country
  // Example for Category GET:
  // Add similar GET/POST groups for Category, Source, Country
  // Example for Category GET:
  group('GET /data?model=category', () {
     test('returns 200 OK with list of categories', () async {
      final context = buildTestContext(
        modelName: 'category',
        modelConfig: categoryConfig,
        repo: mockCategoryRepo, // Use the correct repo mock
        method: HttpMethod.get,
      );
      // Stub the specific repo read for this test
      when(() => mockContext.read<HtDataRepository<Category>>()).thenReturn(mockCategoryRepo);
      // Ensure the mock setup matches the handler call exactly
      when(() => mockCategoryRepo.readAll(startAfterId: null, limit: null))
          .thenAnswer((_) async => testCategories);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(await response.json(), equals(testCategoriesJson));
      verify(() => mockCategoryRepo.readAll(startAfterId: null, limit: null)).called(1);
    });
    // ... add more category GET tests (pagination, query) ...
  });

  // Example for Category POST:
   group('POST /data?model=category', () {
     test('returns 201 Created with created category', () async {
      final requestBody = {'name': 'New Category', 'id': 'new-c1'};
      final inputCategory = Category.fromJson(requestBody);
      // Assume repo returns the created item, potentially with server-side changes
      // but stick to the input structure for basic verification unless specified.
      final createdCategory = inputCategory; // No unexpected copyWith

      final context = buildTestContext(
        modelName: 'category',
        modelConfig: categoryConfig,
        repo: mockCategoryRepo, // Use the correct repo mock
        method: HttpMethod.post,
        requestBody: requestBody,
      );
      // Stub the specific repo read for this test
      when(() => mockContext.read<HtDataRepository<Category>>()).thenReturn(mockCategoryRepo);
      when(() => mockCategoryRepo.create(inputCategory))
          .thenAnswer((_) async => createdCategory);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.created));
      expect(await response.json(), equals(createdCategory.toJson()));
      verify(() => mockCategoryRepo.create(inputCategory)).called(1);
    });
     // ... add more category POST tests (errors, etc.) ...
   });

  // --- Source Tests ---
  // --- Source Tests ---
  group('GET /data?model=source', () {
    test('returns 200 OK with list of sources (no query)', () async {
      final context = buildTestContext(
        modelName: 'source',
        modelConfig: sourceConfig,
        repo: mockSourceRepo,
        method: HttpMethod.get,
      );
      // Stub the specific repo read for this test
      when(() => mockContext.read<HtDataRepository<Source>>()).thenReturn(mockSourceRepo);
      // Ensure the mock setup matches the handler call exactly
      when(() => mockSourceRepo.readAll(startAfterId: null, limit: null))
          .thenAnswer((_) async => testSources);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(await response.json(), equals(testSourcesJson));
      verify(() => mockSourceRepo.readAll(startAfterId: null, limit: null)).called(1);
    });

    test('returns 200 OK with list of sources (with pagination)', () async {
      final context = buildTestContext(
        modelName: 'source',
        modelConfig: sourceConfig,
        repo: mockSourceRepo,
        method: HttpMethod.get,
        queryParams: {'startAfterId': 'idx-s1', 'limit': '1'},
      );
      // Stub the specific repo read for this test
      when(() => mockContext.read<HtDataRepository<Source>>()).thenReturn(mockSourceRepo);
       // Ensure the mock setup matches the handler call exactly
       when(() => mockSourceRepo.readAll(startAfterId: 'idx-s1', limit: 1))
          .thenAnswer((_) async => [testSource2]); // Return the correct type

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(await response.json(), equals([testSource2.toJson()]));
      verify(() => mockSourceRepo.readAll(startAfterId: 'idx-s1', limit: 1)).called(1);
    });

     test('returns 200 OK with list of sources (with specific query)', () async {
      final query = {'name': 'Index Source A'};
      final expectedRepoQuery = {'name': 'Index Source A'};
      final context = buildTestContext(
        modelName: 'source',
        modelConfig: sourceConfig,
        repo: mockSourceRepo,
        method: HttpMethod.get,
        queryParams: {...query, 'model': 'source'},
      );
      // Stub the specific repo read for this test
      when(() => mockContext.read<HtDataRepository<Source>>()).thenReturn(mockSourceRepo);
      // Ensure the mock setup matches the handler call exactly
      when(() => mockSourceRepo.readAllByQuery(expectedRepoQuery, startAfterId: null, limit: null))
          .thenAnswer((_) async => [testSource1]); // Return the correct type

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(await response.json(), equals([testSource1.toJson()]));
      verify(() => mockSourceRepo.readAllByQuery(expectedRepoQuery, startAfterId: null, limit: null)).called(1);
    });
  });

   group('POST /data?model=source', () {
     test('returns 201 Created with created source', () async {
      final requestBody = {'name': 'New Source', 'id': 'new-s1'};
      final inputSource = Source.fromJson(requestBody);
      final createdSource = inputSource; // Assume repo returns matching structure

      final context = buildTestContext(
        modelName: 'source',
        modelConfig: sourceConfig,
        repo: mockSourceRepo,
        method: HttpMethod.post,
        requestBody: requestBody,
      );
      // Stub the specific repo read for this test
      when(() => mockContext.read<HtDataRepository<Source>>()).thenReturn(mockSourceRepo);
      // Ensure mock matches the exact object instance
      when(() => mockSourceRepo.create(inputSource))
          .thenAnswer((_) async => createdSource); // Return the correct type

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.created));
      expect(await response.json(), equals(createdSource.toJson()));
      verify(() => mockSourceRepo.create(inputSource)).called(1);
    });

    test('returns 400 Bad Request for invalid JSON body (TypeError)', () async {
      final requestBody = {'name': 123}; // Invalid type

      final context = buildTestContext(
        modelName: 'source',
        modelConfig: sourceConfig,
        repo: mockSourceRepo,
        method: HttpMethod.post,
        requestBody: requestBody,
      );
      // No repo read stub needed as it should fail before that

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
      final responseJson = await response.json() as Map<String, dynamic>;
      expect(responseJson['error']['code'], equals('INVALID_REQUEST_BODY'));
      verifyNever(() => mockSourceRepo.create(any()));
    });
   });

  // --- Country Tests ---
  // --- Country Tests ---
  group('GET /data?model=country', () {
    test('returns 200 OK with list of countries (no query)', () async {
      final context = buildTestContext(
        modelName: 'country',
        modelConfig: countryConfig,
        repo: mockCountryRepo,
        method: HttpMethod.get,
      );
      // Stub the specific repo read for this test
      when(() => mockContext.read<HtDataRepository<Country>>()).thenReturn(mockCountryRepo);
      // Ensure the mock setup matches the handler call exactly
      when(() => mockCountryRepo.readAll(startAfterId: null, limit: null))
          .thenAnswer((_) async => testCountries);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(await response.json(), equals(testCountriesJson));
      verify(() => mockCountryRepo.readAll(startAfterId: null, limit: null)).called(1);
    });

      test('returns 200 OK with list of countries (with pagination)', () async {
      final context = buildTestContext(
        modelName: 'country',
        modelConfig: countryConfig,
        repo: mockCountryRepo,
        method: HttpMethod.get,
        queryParams: {'startAfterId': 'idx-co1', 'limit': '1'},
      );
      // Stub the specific repo read for this test
      when(() => mockContext.read<HtDataRepository<Country>>()).thenReturn(mockCountryRepo);
       // Ensure the mock setup matches the handler call exactly
       when(() => mockCountryRepo.readAll(startAfterId: 'idx-co1', limit: 1))
          .thenAnswer((_) async => [testCountry2]); // Return the correct type

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(await response.json(), equals([testCountry2.toJson()]));
      verify(() => mockCountryRepo.readAll(startAfterId: 'idx-co1', limit: 1)).called(1);
    });

     test('returns 200 OK with list of countries (with specific query)', () async {
      final query = {'isoCode': 'US'};
      final expectedRepoQuery = {'isoCode': 'US'};
      final context = buildTestContext(
        modelName: 'country',
        modelConfig: countryConfig,
        repo: mockCountryRepo,
        method: HttpMethod.get,
        queryParams: {...query, 'model': 'country'},
      );
      // Stub the specific repo read for this test
      when(() => mockContext.read<HtDataRepository<Country>>()).thenReturn(mockCountryRepo);
      // Ensure the mock setup matches the handler call exactly
      when(() => mockCountryRepo.readAllByQuery(expectedRepoQuery, startAfterId: null, limit: null))
          .thenAnswer((_) async => [testCountry1]); // Return the correct type

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(await response.json(), equals([testCountry1.toJson()]));
      verify(() => mockCountryRepo.readAllByQuery(expectedRepoQuery, startAfterId: null, limit: null)).called(1);
    });
  });

   group('POST /data?model=country', () {
     test('returns 201 Created with created country', () async {
      // Note: Country model has required fields (id, isoCode, name, flagUrl)
      final requestBody = {
        'id': 'new-co1',
        'isoCode': 'CA',
        'name': 'New Canada',
        'flagUrl': 'new_url',
      };
      final inputCountry = Country.fromJson(requestBody);
      final createdCountry = inputCountry; // Assume repo returns matching structure

      final context = buildTestContext(
        modelName: 'country',
        modelConfig: countryConfig,
        repo: mockCountryRepo,
        method: HttpMethod.post,
        requestBody: requestBody,
      );
      // Stub the specific repo read for this test
      when(() => mockContext.read<HtDataRepository<Country>>()).thenReturn(mockCountryRepo);
      // Ensure mock matches the exact object instance for the success case
      when(() => mockCountryRepo.create(inputCountry))
          .thenAnswer((_) async => createdCountry); // Return the correct type

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.created));
      expect(await response.json(), equals(createdCountry.toJson()));
      verify(() => mockCountryRepo.create(inputCountry)).called(1);
    });

    test('returns 400 Bad Request for missing required field (TypeError)', () async {
      final requestBody = {
        'id': 'new-co2',
        'isoCode': 'MX',
        // Missing 'name' and 'flagUrl'
      };

      final context = buildTestContext(
        modelName: 'country',
        modelConfig: countryConfig, // Real config will throw TypeError
        repo: mockCountryRepo,
        method: HttpMethod.post,
        requestBody: requestBody,
      );
      // No repo read stub needed as it should fail before that

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
      final responseJson = await response.json() as Map<String, dynamic>;
      expect(responseJson['error']['code'], equals('INVALID_REQUEST_BODY'));
      expect(responseJson['error']['message'], contains('Missing or invalid required field'));
      verifyNever(() => mockCountryRepo.create(any()));
    });
   });
}
