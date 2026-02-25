import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart' show DataRepository;
import 'package:flutter_news_app_api_server_full_source_code/src/clients/analytics/analytics_reporting_client.dart'
    show AnalyticsReportingClient;
import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart';
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
    HttpClient? httpClient,
  }) : _projectId = projectId,
       _log = log,
       _headlineRepository = headlineRepository,
       _httpClient =
           httpClient ??
           _createDefaultHttpClient(
             serviceAccountUsername,
             serviceAccountSecret,
             log,
           );

  final String _projectId;
  late final HttpClient _httpClient;
  final Logger _log;
  final DataRepository<Headline> _headlineRepository;

  // A private static method to create the default HttpClient.
  // This keeps the constructor clean and allows for easy test injection.
  static HttpClient _createDefaultHttpClient(
    String username,
    String secret,
    Logger log,
  ) {
    final credentials = base64Encode('$username:$secret'.codeUnits);
    return HttpClient(
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
      logger: log,
    );
  }

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
      metricName = r'$active';
    }

    _log.info('Fetching time series for metric "$metricName" from Mixpanel.');

    String? whereClause;
    if (query is EventCountQuery &&
        query.properties != null &&
        query.properties!.isNotEmpty) {
      whereClause = query.properties!.entries
          .map((e) => 'properties["${e.key}"] == "${e.value}"')
          .join(' and ');
    }

    final request = MixpanelSegmentationRequest(
      projectId: _projectId,
      event: metricName,
      fromDate: DateFormat('yyyy-MM-dd').format(startDate),
      toDate: DateFormat('yyyy-MM-dd').format(endDate),
      unit: MixpanelTimeUnit.day,
      where: whereClause,
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
    final values = segmentationData.values[metricName] ?? [];

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
      metricName = r'$active';
    }

    _log.info('Fetching total for metric "$metricName" from Mixpanel.');

    // To get a single total, we call the segmentation endpoint without the 'unit'
    // parameter. The MixpanelSegmentationRequest model supports this by having
    // a nullable 'unit'.
    String? whereClause;
    if (query is EventCountQuery &&
        query.properties != null &&
        query.properties!.isNotEmpty) {
      whereClause = query.properties!.entries
          .map((e) => 'properties["${e.key}"] == "${e.value}"')
          .join(' and ');
    }

    final request = MixpanelSegmentationRequest(
      projectId: _projectId,
      event: metricName,
      fromDate: DateFormat('yyyy-MM-dd').format(startDate),
      toDate: DateFormat('yyyy-MM-dd').format(endDate),
      where: whereClause,
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

    // The response for a total value has a single entry in the 'values' map.
    if (segmentationData.values.values.isEmpty ||
        segmentationData.values.values.first.isEmpty) {
      return 0;
    }
    // Sum all values in the first (and typically only) list of values.
    return segmentationData.values.values.first.fold<num>(
      0,
      (previousValue, element) => previousValue + (element as num),
    );
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
          displayTitle: const {},
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
            displayTitle:
                headlineMap[item.entityId] ??
                {SupportedLanguage.en: 'Unknown Headline'},
          ),
        )
        .toList();
  }

  @override
  Future<Map<GARequestDateRange, List<DataPoint>>> getTimeSeriesBatch(
    MetricQuery query,
    List<GARequestDateRange> ranges,
  ) async {
    _log.info(
      'Executing pseudo-batch for getTimeSeries with ${ranges.length} ranges '
      'for Mixpanel (parallel requests).',
    );
    final futures = ranges.map(
      (range) => getTimeSeries(
        query,
        DateTime.parse(range.startDate),
        DateTime.parse(range.endDate),
      ),
    );

    final results = await Future.wait(futures);

    return {
      for (var i = 0; i < ranges.length; i++) ranges[i]: results[i],
    };
  }

  @override
  Future<Map<GARequestDateRange, num>> getMetricTotalsBatch(
    MetricQuery query,
    List<GARequestDateRange> ranges,
  ) async {
    _log.info(
      'Executing pseudo-batch for getMetricTotalsBatch with ${ranges.length} '
      'ranges for Mixpanel (parallel requests).',
    );
    final futures = ranges.map(
      (range) => getMetricTotal(
        query,
        DateTime.parse(range.startDate),
        DateTime.parse(range.endDate),
      ),
    );

    final results = await Future.wait(futures);

    return {for (var i = 0; i < ranges.length; i++) ranges[i]: results[i]};
  }
}
