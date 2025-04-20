import 'dart:async';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_countries_client/ht_countries_client.dart';

/// Handles requests to `/countries/{isoCode}`.
///
/// Supports:
/// - `GET`: Fetches a single country by its ISO code.
/// - `PUT`: Updates an existing country.
///   - Request Body: JSON representation of the updated [Country] object.
///     The `isoCode` in the body *must* match the `isoCode` in the path.
/// - `DELETE`: Deletes a country by its ISO code.
Future<Response> onRequest(RequestContext context, String isoCode) async {
  // Read the HtCountriesClient instance provided by the middleware.
  final client = context.read<HtCountriesClient>();
  // Sanitize the isoCode from the path (e.g., convert to uppercase).
  final sanitizedIsoCode = isoCode.toUpperCase();

  switch (context.request.method) {
    case HttpMethod.get:
      return _getCountry(context, client, sanitizedIsoCode);
    case HttpMethod.put:
      return _updateCountry(context, client, sanitizedIsoCode);
    case HttpMethod.delete:
      return _deleteCountry(context, client, sanitizedIsoCode);
    case HttpMethod.post:
    case HttpMethod.head:
    case HttpMethod.options:
    case HttpMethod.patch:
      // Return 405 Method Not Allowed for unsupported methods on this path.
      return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}

/// Handles GET requests to fetch a single country.
Future<Response> _getCountry(
  RequestContext context,
  HtCountriesClient client,
  String isoCode,
) async {
  // Fetch the country using the client.
  // The global error handler will catch CountryNotFound and
  // CountryFetchFailure.
  final country = await client.fetchCountry(isoCode);

  // Return the country details as JSON.
  return Response.json(body: country.toJson());
}

/// Handles PUT requests to update a country.
Future<Response> _updateCountry(
  RequestContext context,
  HtCountriesClient client,
  String pathIsoCode, // ISO code from the URL path
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

  Country countryToUpdate;
  try {
    // Attempt to create a Country object from the parsed JSON.
    countryToUpdate = Country.fromJson(requestBody);
  } on FormatException catch (e) {
    // Return 400 if the JSON structure is invalid for a Country.
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': 'Invalid country data: ${e.message}'},
    );
  }

  // --- Validation ---
  // Ensure the ISO code in the path matches the ISO code in the request body.
  final bodyIsoCode = countryToUpdate.isoCode.toUpperCase();
  if (bodyIsoCode != pathIsoCode) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {
        'error':
            'ISO code in request body ("$bodyIsoCode") does not match ISO code '
                'in URL path ("$pathIsoCode").',
      },
    );
  }
  // --- End Validation ---

  // Update the country using the client.
  // The global error handler will catch CountryNotFound and
  // CountryUpdateFailure.
  // Pass the validated country object from the body.
  await client.updateCountry(countryToUpdate);

  // Return 200 OK on successful update.
  return Response();
}

/// Handles DELETE requests to delete a country.
Future<Response> _deleteCountry(
  RequestContext context,
  HtCountriesClient client,
  String isoCode,
) async {
  // Delete the country using the client.
  // The global error handler will catch CountryNotFound and
  // CountryDeleteFailure.
  await client.deleteCountry(isoCode);

  // Return 204 No Content on successful deletion.
  return Response(statusCode: HttpStatus.noContent);
}
