//
// ignore_for_file: avoid_slow_async_io, avoid_catches_without_on_clauses

import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/middlewares/error_handler.dart';
import 'package:ht_api/src/registry/model_registry.dart';
import 'package:ht_data_inmemory/ht_data_inmemory.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_shared/ht_shared.dart';

// --- Helper Function to Load Fixtures ---
// Note:
// Error handling here is basic. In a real app,
// consider more robust file checks.
// ignore: unused_element
Future<List<Map<String, dynamic>>> _loadFixture(String fileName) async {
  final path = 'lib/src/fixtures/$fileName';
  try {
    final file = File(path);
    if (!await file.exists()) {
      print('Warning: Fixture file not found at $path. Returning empty list.');
      return [];
    }
    final content = await file.readAsString();
    final decoded = jsonDecode(content) as List<dynamic>?; // Allow null
    // Ensure items are maps
    return decoded?.whereType<Map<String, dynamic>>().toList() ?? [];
  } catch (e) {
    print('Error loading or parsing fixture file $path: $e');
    return []; // Return empty on error to avoid crashing startup
  }
}

// --- Repository Creation Logic ---
// Synchronous fixture loader (use with caution)
List<Map<String, dynamic>> _loadFixtureSync(String fileName) {
  final path = 'lib/src/fixtures/$fileName';
  try {
    final file = File(path);
    if (!file.existsSync()) {
      print('Warning: Fixture file not found at $path. Returning empty list.');
      return [];
    }
    final content = file.readAsStringSync();
    final decoded = jsonDecode(content) as List<dynamic>?;
    return decoded?.whereType<Map<String, dynamic>>().toList() ?? [];
  } catch (e) {
    print('Error loading or parsing fixture file $path: $e');
    return [];
  }
}

HtDataRepository<Headline> _createHeadlineRepository() {
  print('Initializing Headline Repository...');
  final initialData =
      _loadFixtureSync('headlines.json').map(Headline.fromJson).toList();
  final client = HtDataInMemoryClient<Headline>(
    toJson: (i) => i.toJson(),
    getId: (i) => i.id,
    initialData: initialData,
  );
  print('Headline Repository Initialized with ${initialData.length} items.');
  return HtDataRepository<Headline>(dataClient: client);
}

HtDataRepository<Category> _createCategoryRepository() {
  print('Initializing Category Repository...');
  final initialData =
      _loadFixtureSync('categories.json').map(Category.fromJson).toList();
  final client = HtDataInMemoryClient<Category>(
    toJson: (i) => i.toJson(),
    getId: (i) => i.id,
    initialData: initialData,
  );
  print('Category Repository Initialized with ${initialData.length} items.');
  return HtDataRepository<Category>(dataClient: client);
}

HtDataRepository<Source> _createSourceRepository() {
  print('Initializing Source Repository...');
  final initialData =
      _loadFixtureSync('sources.json').map(Source.fromJson).toList();
  final client = HtDataInMemoryClient<Source>(
    toJson: (i) => i.toJson(),
    getId: (i) => i.id,
    initialData: initialData,
  );
  print('Source Repository Initialized with ${initialData.length} items.');
  return HtDataRepository<Source>(dataClient: client);
}

HtDataRepository<Country> _createCountryRepository() {
  print('Initializing Country Repository...');
  final initialData =
      _loadFixtureSync('countries.json').map(Country.fromJson).toList();
  final client = HtDataInMemoryClient<Country>(
    toJson: (i) => i.toJson(),
    getId: (i) => i.id,
    initialData: initialData,
  );
  print('Country Repository Initialized with ${initialData.length} items.');
  return HtDataRepository<Country>(dataClient: client);
}

// --- Middleware Definition ---
Handler middleware(Handler handler) {
  // Initialize repositories when middleware is first created
  // This ensures they are singletons for the server instance.
  final headlineRepository = _createHeadlineRepository();
  final categoryRepository = _createCategoryRepository();
  final sourceRepository = _createSourceRepository();
  final countryRepository = _createCountryRepository();

  // Chain the providers and other middleware
  return handler
      // Provide the Model Registry Map
      .use(
        modelRegistryProvider,
      ) // Uses the provider defined in model_registry.dart

      // Provide each specific repository instance
      .use(provider<HtDataRepository<Headline>>((_) => headlineRepository))
      .use(provider<HtDataRepository<Category>>((_) => categoryRepository))
      .use(provider<HtDataRepository<Source>>((_) => sourceRepository))
      .use(provider<HtDataRepository<Country>>((_) => countryRepository))

      // Add other essential middleware like error handling
      .use(requestLogger()) // Basic request logging
      .use(errorHandler()); // Centralized error handling
}
