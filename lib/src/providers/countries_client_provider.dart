import 'package:dart_frog/dart_frog.dart';
import 'package:ht_countries_client/ht_countries_client.dart';
import 'package:meta/meta.dart'; // For @visibleForTesting

/// Provides an instance of [HtCountriesClient] to the request context.
///
/// This middleware is responsible for creating or obtaining the client instance
/// (e.g., based on environment variables or configuration) and making it
/// available via `context.read<HtCountriesClient>()` in subsequent handlers
/// and middleware.
Middleware countriesClientProvider() {
  return provider<HtCountriesClient>(
    (context) {
      // TODO(fulleni): Replace this with your actual HtCountriesClient
      // implementation.
      //
      // This could involve reading configuration, setting up database
      // connections, or initializing an HTTP client depending on your
      // chosen backend.
      //
      // Example:
      // final firestore = Firestore.instance; // If using Firestore
      // return FirestoreHtCountriesClient(firestore);
      //
      // final dio = Dio(); // If using an HTTP API
      // return ApiHtCountriesClient(dio);

      // For development/testing purposes, we provide an in-memory mock.
      // DO NOT use this in production.
      print(
        'WARNING: Using InMemoryHtCountriesClient. Replace for production!',
      );
      return InMemoryHtCountriesClient();
    },
  );
}

/// {@template in_memory_ht_countries_client}
/// A simple in-memory implementation of [HtCountriesClient] for testing
/// and development purposes.
///
/// **Do not use this in production.**
/// {@endtemplate}
@visibleForTesting
class InMemoryHtCountriesClient implements HtCountriesClient {
  /// {@macro in_memory_ht_countries_client}
  InMemoryHtCountriesClient() {
    // Initialize with some sample data
    _countries = {
      'US': Country(
        isoCode: 'US',
        name: 'United States',
        flagUrl: 'https://example.com/flags/us.png',
      ),
      'CA': Country(
        isoCode: 'CA',
        name: 'Canada',
        flagUrl: 'https://example.com/flags/ca.png',
      ),
      'GB': Country(
        isoCode: 'GB',
        name: 'United Kingdom',
        flagUrl: 'https://example.com/flags/gb.png',
      ),
      'DZ': Country(
        isoCode: 'DZ',
        name: 'Algeria',
        flagUrl: 'https://example.com/flags/dz.png',
      ),
    };
  }

  /// Internal storage for countries, mapping ISO code to Country object.
  late final Map<String, Country> _countries;

  @override
  Future<List<Country>> fetchCountries({
    required int limit,
    String? startAfterId,
  }) async {
    await _simulateDelay();
    final countryList = _countries.values.toList()
      ..sort((a, b) => a.isoCode.compareTo(b.isoCode)); // Consistent order

    var startIndex = 0;
    if (startAfterId != null) {
      final startAfterCountry = _countries.values.firstWhere(
        (c) => c.id == startAfterId,
        orElse: () => throw const CountryNotFound('StartAfterId not found'),
      );
      final index = countryList.indexWhere((c) => c.id == startAfterCountry.id);
      if (index != -1) {
        startIndex = index + 1;
      } else {
        // Should not happen if startAfterId was valid, but handle defensively
        throw const CountryNotFound('StartAfterId inconsistency');
      }
    }

    if (startIndex >= countryList.length) {
      return []; // No more items after the specified ID
    }

    final endIndex = (startIndex + limit).clamp(0, countryList.length);
    return countryList.sublist(startIndex, endIndex);
  }

  @override
  Future<Country> fetchCountry(String isoCode) async {
    await _simulateDelay();
    final country = _countries[isoCode.toUpperCase()];
    if (country == null) {
      throw CountryNotFound('Country with ISO code $isoCode not found.');
    }
    return country;
  }

  @override
  Future<void> createCountry(Country country) async {
    await _simulateDelay();
    final upperIsoCode = country.isoCode.toUpperCase();
    if (_countries.containsKey(upperIsoCode)) {
      throw CountryCreateFailure(
        'Country with ISO code $upperIsoCode already exists.',
      );
    }
    // Ensure ID is generated if not provided (though constructor handles this)
    final countryWithId = Country(
      id: country.id, // Use existing or generate new
      isoCode: upperIsoCode,
      name: country.name,
      flagUrl: country.flagUrl,
    );
    _countries[upperIsoCode] = countryWithId;
  }

  @override
  Future<void> updateCountry(Country country) async {
    await _simulateDelay();
    final upperIsoCode = country.isoCode.toUpperCase();
    if (!_countries.containsKey(upperIsoCode)) {
      throw CountryNotFound('Country with ISO code $upperIsoCode not found.');
    }
    // Update using the provided country data, keeping the original ID if needed
    // or ensuring the provided one is used consistently.
    _countries[upperIsoCode] = country;
  }

  @override
  Future<void> deleteCountry(String isoCode) async {
    await _simulateDelay();
    final upperIsoCode = isoCode.toUpperCase();
    if (!_countries.containsKey(upperIsoCode)) {
      throw CountryNotFound('Country with ISO code $upperIsoCode not found.');
    }
    _countries.remove(upperIsoCode);
  }

  /// Helper to simulate network latency.
  Future<void> _simulateDelay() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
