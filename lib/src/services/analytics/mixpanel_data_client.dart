import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/analytics/analytics.dart';
import 'package:http_client/http_client.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

/// {@template mixpanel_data_client}
/// A concrete implementation of [AnalyticsReportingClient] for fetching data
/// from the Mixpanel API.
/// {@endtemplate}
class MixpanelDataClient implements AnalyticsReportingClient {
  /// {@macro mixpanel_data_client}
  MixpanelDataClient({
    required String projectId,
    required String serviceAccountUsername,
    required String serviceAccountSecret,
    required Logger log,
  }) : _projectId = projectId,
       _serviceAccountUsername = serviceAccountUsername,
       _serviceAccountSecret = serviceAccountSecret,
       _log = log {
    final credentials = base64Encode(
      '$_serviceAccountUsername:$_serviceAccountSecret'.codeUnits,
    );
    _httpClient = HttpClient(
      baseUrl: 'https://mixpanel.com/api/2.0',
      // Mixpanel uses Basic Auth with a service account.
      // We inject the header directly via an interceptor.
      tokenProvider: () async => null,
      interceptors: [
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers['Authorization'] = 'Basic $credentials';
            return handler.next(options);
          },
        ),
      ],
      logger: _log,
    );
  }

  final String _projectId;
  final String _serviceAccountUsername;
  final String _serviceAccountSecret;
  late final HttpClient _httpClient;
  final Logger _log;

  @override
  Future<List<DataPoint>> getTimeSeries(
    String metricName,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _log.info('Fetching time series for metric "$metricName" from Mixpanel.');

    final response = await _httpClient.get<Map<String, dynamic>>(
      '/segmentation',
      queryParameters: {
        'project_id': _projectId,
        'event': metricName,
        'from_date': DateFormat('yyyy-MM-dd').format(startDate),
        'to_date': DateFormat('yyyy-MM-dd').format(endDate),
        'unit': 'day',
      },
    );

    final segmentationData =
        MixpanelResponse<MixpanelSegmentationData>.fromJson(
          response,
          (json) =>
              MixpanelSegmentationData.fromJson(json as Map<String, dynamic>),
        ).data;

    final dataPoints = <DataPoint>[];
    final series = segmentationData.series;
    final values = segmentationData.values.values.firstOrNull ?? [];

    for (var i = 0; i < series.length; i++) {
      dataPoints.add(
        DataPoint(
          timestamp: DateTime.parse(series[i]),
          value: values.isNotEmpty ? values[i] : 0,
        ),
      );
    }
    return dataPoints;
  }

  @override
  Future<num> getMetricTotal(
    String metricName,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _log.warning('getMetricTotal for Mixpanel is not implemented.');
    return 0;
  }

  @override
  Future<List<RankedListItem>> getRankedList(
    String dimensionName,
    String metricName,
  ) async {
    _log.warning('getRankedList for Mixpanel is not implemented.');
    return [];
  }
}
