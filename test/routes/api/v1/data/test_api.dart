import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/error_handler.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/data_operation_registry.dart';

import '../../../../../routes/api/v1/data/[id]/_middleware.dart'
    as item_middleware;
import '../../../../../routes/api/v1/data/[id]/index.dart' as item_index;
import '../../../../../routes/api/v1/data/_middleware.dart' as data_middleware;
import '../../../../../routes/api/v1/data/index.dart' as index;
import '../../../../src/helpers/test_helpers.dart';

class TestApi {
  TestApi.from(this.contextBuilder);
  final RequestContext Function(RequestContext) contextBuilder;

  Future<Response> get(String path, {Map<String, String>? headers}) =>
      _handle(HttpMethod.get, path, headers);

  Future<Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => _handle(HttpMethod.post, path, headers, body);

  Future<Response> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => _handle(HttpMethod.put, path, headers, body);

  Future<Response> delete(String path, {Map<String, String>? headers}) =>
      _handle(HttpMethod.delete, path, headers);

  Future<Response> _handle(
    HttpMethod method,
    String path,
    Map<String, String>? headers, [
    Object? body,
  ]) async {
    final uri = Uri.parse('http://localhost$path');
    final queryParams = uri.queryParameters;
    final modelName = queryParams['model'];

    // Create a real Request object to ensure integration tests use the
    // actual framework logic for request parsing.
    final request = Request(
      method.value,
      uri,
      headers: headers,
      body: body as String?,
    );

    // Use the helper to create a TestRequestContext populated with the
    // real request and necessary dependencies.
    // CRITICAL: We must explicitly pass the body here so the TestRequestContext
    // is initialized with it.
    var context = createMockRequestContext(
      request: request,
      modelName: modelName,
      body: body,
    );

    context = contextBuilder(context);

    // Ensure DataOperationRegistry is provided.
    // The real registry uses the repositories provided in the context (which are mocks in tests).
    context = context.provide<DataOperationRegistry>(
      DataOperationRegistry.new,
    );

    // We use authenticationProvider directly to avoid CORS middleware (fromShelfMiddleware)
    // which crashes with MockRequest.
    // We also MUST include errorHandler to convert Exceptions to Responses.
    final handler = errorHandler()(
      authenticationProvider()(
        data_middleware.middleware((RequestContext ctx) async {
          // Check for item requests: /api/v1/data/[id] -> 4 segments
          if (uri.pathSegments.length == 4) {
            final id = uri.pathSegments.last;

            // Construct the item handler chain manually to include item-specific middleware
            // (like ownership checks) which are critical for these tests.
            Handler itemHandler = (c) => item_index.onRequest(c, id);
            itemHandler = item_middleware.middleware(itemHandler);

            return itemHandler(ctx);
          }

          // Fallback to collection handler
          return index.onRequest(ctx);
        }),
      ),
    );

    return handler(context);
  }
}
