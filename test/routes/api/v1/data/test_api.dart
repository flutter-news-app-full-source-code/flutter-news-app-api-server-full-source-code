import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/data_operation_registry.dart';

import '../../../../../routes/api/v1/data/_middleware.dart' as middleware;
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

    var context = createMockRequestContext(
      method: method,
      path: path,
      headers: headers ?? {},
      queryParams: queryParams,
      body: body,
      modelName: modelName,
    );

    context = contextBuilder(context);

    final handler = middleware.middleware((RequestContext ctx) async {
      if (uri.pathSegments.length > 4) {
        // /api/v1/data/[id]
        final id = uri.pathSegments.last;
        final registry = ctx.read<DataOperationRegistry>();
        final modelName = ctx.read<String>();

        if (method == HttpMethod.get) {
          final fetcher = registry.itemFetchers[modelName]!;
          final item = await fetcher(ctx, id);
          return Response.json(body: {'data': item});
        } else if (method == HttpMethod.put) {
          final updater = registry.itemUpdaters[modelName]!;
          final body = await ctx.request.json();
          final item = await updater(ctx, id, body, ctx.read<User?>()?.id);
          return Response.json(body: {'data': item});
        } else if (method == HttpMethod.delete) {
          final deleter = registry.itemDeleters[modelName]!;
          await deleter(ctx, id, ctx.read<User?>()?.id);
          return Response(statusCode: 204);
        }
        return Response(statusCode: 405);
      } else {
        return index.onRequest(ctx);
      }
    });

    return handler(context);
  }
}
