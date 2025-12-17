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
  }) : _projectId = projectId,
       _serviceAccountUsername = serviceAccountUsername,
       _serviceAccountSecret = serviceAccountSecret,
       _log = log,
       _headlineRepository = headlineRepository {
    final credentials = base64Encode(
      '$_serviceAccountUsername:$_serviceAccountSecret'.codeUnits,
    );
    _httpClient = HttpClient(
      baseUrl: 'https://mixpanel.com/api/2.0',
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

  String _getMetricName(MetricQuery query) {
    return switch (query) {
      EventCountQuery(event: final e) => e.name,
      StandardMetricQuery(metric: final m) => m,
    };
  }

  @override
  Future<List<DataPoint>> getTimeSeries(
    MetricQuery query,
    DateTime startDate,
    DateTime endDate,
  ) async {
    var metricName = _getMetricName(query);
    if (metricName.startsWith('database:')) {
      throw ArgumentError.value(
        query,
        'query',
        'Database queries cannot be handled by MixpanelDataClient.',
      );
    }
    if (metricName == 'activeUsers') {
      // Mixpanel uses a special name for active users.
      metricName = '\$active';
    }

    _log.info('Fetching time series for metric "$metricName" from Mixpanel.');

    final request = MixpanelSegmentationRequest(
      projectId: _projectId,
      event: metricName,
      fromDate: DateFormat('yyyy-MM-dd').format(startDate),
      toDate: DateFormat('yyyy-MM-dd').format(endDate),
    );

    final response = await _httpClient.get<Map<String, dynamic>>(
      '/segmentation',
      queryParameters: request.toJson(),
    );

    final segmentationData =
        MixpanelResponse<MixpanelSegmentationData>.fromJson(
          response,
          (json) =>
              MixpanelSegmentationData.fromJson(json as Map<String, dynamic>),
        ).data;

    final dataPoints = <DataPoint>[];
    final series = segmentationData.series;
    final values =
        segmentationData.values[metricName] ??
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
    MetricQuery query,
    DateTime startDate,
    DateTime endDate,
  ) async {
    var metricName = _getMetricName(query);
    if (metricName.startsWith('database:')) {
      throw ArgumentError.value(
        query,
        'query',
        'Database queries cannot be handled by MixpanelDataClient.',
      );
    }
    if (metricName == 'activeUsers') {
      // Mixpanel uses a special name for active users.
      metricName = '\$active';
    }

    _log.info('Fetching total for metric "$metricName" from Mixpanel.');
    final timeSeries = await getTimeSeries(query, startDate, endDate);
    if (timeSeries.isEmpty) return 0;

    return timeSeries.map((dp) => dp.value).reduce((a, b) => a + b);
  }

  @override
  Future<List<RankedListItem>> getRankedList(
    RankedListQuery query,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final metricName = query.event.name;
    final dimensionName = query.dimension;
    _log.info(
      'Fetching ranked list for dimension "$dimensionName" by metric '
      '"$metricName" from Mixpanel.',
    );

    final request = MixpanelTopEventsRequest(
      projectId: _projectId,
      event: metricName,
      name: dimensionName,
      fromDate: DateFormat('yyyy-MM-dd').format(startDate),
      toDate: DateFormat('yyyy-MM-dd').format(endDate),
      limit: query.limit,
    );

    final response = await _httpClient.get<Map<String, dynamic>>(
      '/events/properties/top',
      queryParameters: request.toJson(),
    );

    final rawItems = <RankedListItem>[];
    response.forEach((key, value) {
      if (value is! Map || !value.containsKey('count')) return;
      final count = value['count'];
      if (count is! num) return;

      rawItems.add(
        RankedListItem(
          entityId: key,
          displayTitle: '',
          metricValue: count,
        ),
      );
    });

    rawItems.sort((a, b) => b.metricValue.compareTo(a.metricValue));

    final headlineIds = rawItems.map((item) => item.entityId).toList();
    if (headlineIds.isEmpty) return [];

    final paginatedHeadlines = await _headlineRepository.readAll(
      filter: {
        '_id': {r'$in': headlineIds},
      },
    );
    final headlineMap = {
      for (final h in paginatedHeadlines.items) h.id: h.title,
    };

    return rawItems
        .map(
          (item) => item.copyWith(
            displayTitle: headlineMap[item.entityId] ?? 'Unknown Headline',
          ),
        )
        .toList();
  }
}
