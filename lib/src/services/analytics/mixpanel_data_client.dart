import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
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
    required DataRepository<Headline> headlineRepository,
  })  : _projectId = projectId,
        _serviceAccountUsername = serviceAccountUsername,
        _serviceAccountSecret = serviceAccountSecret,
        _log = log,
        _headlineRepository = headlineRepository {
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
  final DataRepository<Headline> _headlineRepository;

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
    final values = segmentationData.values[metricName] ??
        segmentationData.values.values.firstOrNull ??
        [];

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
    _log.info('Fetching total for metric "$metricName" from Mixpanel.');
    final timeSeries = await getTimeSeries(metricName, startDate, endDate);
    if (timeSeries.isEmpty) return 0;

    return timeSeries.map((dp) => dp.value).reduce((a, b) => a + b);
  }

  @override
  Future<List<RankedListItem>> getRankedList(
    String dimensionName,
    String metricName,
    DateTime startDate,
    DateTime endDate, {
    int limit = 5,
  }) async {
    _log.info(
      'Fetching ranked list for dimension "$dimensionName" by metric '
      '"$metricName" from Mixpanel.',
    );

    final response = await _httpClient.get<Map<String, dynamic>>(
      '/events/properties/top',
      queryParameters: {
        'project_id': _projectId,
        'event': metricName,
        'name': dimensionName,
        'from_date': DateFormat('yyyy-MM-dd').format(startDate),
        'to_date': DateFormat('yyyy-MM-dd').format(endDate),
        'limit': limit,
      },
    );

    final items = <RankedListItem>[];
    response.forEach((key, value) {
      if (value is! Map || !value.containsKey('count')) return;
      final count = value['count'];
      if (count is! num) return;

      items.add(
        RankedListItem(
          entityId: key,
          displayTitle: '',
          metricValue: count,
        ),
      );
    });

    items.sort((a, b) => b.metricValue.compareTo(a.metricValue));

    return items;
  }
}
