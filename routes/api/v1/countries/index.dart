import 'dart:async';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_countries_client/ht_countries_client.dart';

/// Default number of countries to return per page if limit is not specified.
const _defaultLimit = 20;

/// Maximum number of countries allowed per page.
const _maxLimit = 100;

/// Handles requests to `/countries`.
///
/// Supports:
/// - `GET`: Fetches a paginated list of countries.
///   - Query Parameters:
///     - `limit` (int, optional): Max number of items per page.
///       Defaults to 20, max 100.
///     - `startAfterId` (String, optional): ID of the last item from the
///       previous page for cursor-based pagination.
/// - `POST`: Creates a new country.
///   - Request Body: JSON representation of the [Country] object to create.
Future<Response> onRequest(RequestContext context) async {
  // Read the HtCountriesClient instance provided by the middleware.
  final client = context.read<HtCountriesClient>();

  switch (context.request.method) {
    case HttpMethod.get:
      return _getCountries(context, client);
    case HttpMethod.post:
      return _createCountry(context, client);
    case HttpMethod.put:
    case HttpMethod.delete:
    case HttpMethod.head:
    case HttpMethod.options:
    case HttpMethod.patch:
      // Return 405 Method Not Allowed for unsupported methods on this path.
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

/// Handles GET requests to fetch a list of countries.
Future<Response> _getCountries(
  RequestContext context,
  HtCountriesClient client,
) async {
  final params = context.request.uri.queryParameters;
  final startAfterId = params['startAfterId'];
  int limit;

  try {
    // Parse limit, apply default and max constraints.
    limit = int.tryParse(params['limit'] ?? '') ?? _defaultLimit;
    limit = limit.clamp(1, _maxLimit); // Ensure limit is within valid range
  } catch (e) {
    // Return 400 if limit parsing fails.
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Invalid query parameter: "limit" must be an integer.',
    );
  }

  // Fetch countries using the client.
  // The global error handler will catch CountryFetchFailure.
  final countries = await client.fetchCountries(
    limit: limit,
    startAfterId: startAfterId,
  );

  // Convert the list of Country objects to a list of JSON maps.
  final jsonList = countries.map((country) => country.toJson()).toList();

  // Return the list as a JSON response.
  return Response.json(body: jsonList);
}

/// Handles POST requests to create a new country.
Future<Response> _createCountry(
  RequestContext context,
  HtCountriesClient client,
) async {
  Map<String, dynamic> requestBody;
  try {
    // Read and parse the JSON body from the request.
    requestBody = await context.request.json() as Map<String, dynamic>;
  } catch (e) {
    // Return 400 if JSON parsing fails.
    return Response(
      statusCode: HttpStatus.badRequest,
      body: 'Invalid JSON format in request body.',
    );
  }

  Country countryToCreate;
  try {
    // Attempt to create a Country object from the parsed JSON.
    // This uses the factory constructor which includes validation.
    countryToCreate = Country.fromJson(requestBody);
  } on FormatException catch (e) {
    // Return 400 if the JSON structure is invalid for a Country.
    // The global error handler also catches FormatException, but catching
    // it here provides a slightly more specific context (request body).
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': 'Invalid country data: ${e.message}'},
    );
  }

  // Create the country using the client.
  // The global error handler will catch CountryCreateFailure.
  await client.createCountry(countryToCreate);

  // Return 201 Created on success.
  // Optionally, could return the created resource with a Location header.
  return Response(statusCode: HttpStatus.created);
}
