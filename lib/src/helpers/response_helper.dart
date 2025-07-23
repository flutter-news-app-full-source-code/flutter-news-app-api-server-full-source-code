import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/request_id.dart';

/// A utility class to simplify the creation of standardized API responses.
abstract final class ResponseHelper {
  /// Creates a standardized success JSON response.
  ///
  /// This helper encapsulates the boilerplate of creating metadata, wrapping the
  /// payload in a [SuccessApiResponse], and serializing it to JSON.
  ///
  /// - [context]: The request context, used to read the `RequestId`.
  /// - [data]: The payload to be included in the response.
  /// - [toJsonT]: A function that knows how to serialize the [data] payload.
  ///   This is necessary because of Dart's generics. For a simple object, this
  ///   would be `(data) => data.toJson()`. For a paginated list, it would be
  ///   `(paginated) => paginated.toJson((item) => item.toJson())`.
  /// - [statusCode]: The HTTP status code for the response. Defaults to 200 OK.
  static Response success<T>({
    required RequestContext context,
    required T data,
    required Map<String, dynamic> Function(T data) toJsonT,
    int statusCode = HttpStatus.ok,
  }) {
    final metadata = ResponseMetadata(
      requestId: context.read<RequestId>().id,
      timestamp: DateTime.now().toUtc(),
    );

    final responsePayload = SuccessApiResponse<T>(
      data: data,
      metadata: metadata,
    );

    return Response.json(
      statusCode: statusCode,
      body: responsePayload.toJson(toJsonT),
    );
  }
}
