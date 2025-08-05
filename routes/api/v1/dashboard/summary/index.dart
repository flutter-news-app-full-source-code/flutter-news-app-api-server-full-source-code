import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/helpers/response_helper.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/dashboard_summary_service.dart';

/// Handles requests for the /api/v1/dashboard/summary endpoint.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get) {
    return _handleGet(context);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}

/// Handles GET requests: Retrieves the dashboard summary.
Future<Response> _handleGet(RequestContext context) async {
  final summaryService = context.read<DashboardSummaryService>();
  final summary = await summaryService.getSummary();

  return ResponseHelper.success(
    context: context,
    data: summary,
    toJsonT: (data) => data.toJson(),
  );
}
