import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/analytics/analytics.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/google_auth_service.dart';
import 'package:http_client/http_client.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

/// {@template google_analytics_data_client}
/// A concrete implementation of [AnalyticsReportingClient] for fetching data
/// from the Google Analytics Data API (v1beta).
///
/// This client is responsible for constructing and sending `runReport` requests
/// to the GA4 property associated with the Firebase project.
/// {@endtemplate}
class GoogleAnalyticsDataClient implements AnalyticsReportingClient {
  /// {@macro google_analytics_data_client}
  GoogleAnalyticsDataClient({
    required String propertyId,
    required IGoogleAuthService firebaseAuthenticator,
    required Logger log,
    required DataRepository<Headline> headlineRepository,
    HttpClient? httpClient,
  }) : _propertyId = propertyId,
       _log = log,
       _headlineRepository = headlineRepository,
       _httpClient =
           httpClient ??
           HttpClient(
             baseUrl: 'https://analyticsdata.googleapis.com/v1beta',
             tokenProvider: () => firebaseAuthenticator.getAccessToken(
               scope: 'https://www.googleapis.com/auth/analytics.readonly',
             ),
             logger: log,
           );

  final String _propertyId;
  final HttpClient _httpClient;
  final Logger _log;
  final DataRepository<Headline> _headlineRepository;

  String _getMetricName(MetricQuery query) {
    return switch (query) {
      EventCountQuery() => 'eventCount',
      StandardMetricQuery(metric: final m) => m,
    };
  }

  @override
  Future<List<DataPoint>> getTimeSeries(
    MetricQuery query,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final metricName = _getMetricName(query);
    if (metricName.startsWith('database:')) {
      throw ArgumentError.value(
        query,
        'query',
        'Database queries cannot be handled by GoogleAnalyticsDataClient.',
      );
    }

    _log.info(
      'Fetching time series for metric "$metricName" from Google Analytics.',
    );

    final request = RunReportRequest(
      dateRanges: [
        GARequestDateRange(
          startDate: DateFormat('y-MM-dd').format(startDate),
          endDate: DateFormat('y-MM-dd').format(endDate),
        ),
      ],
      dimensions: const [
        GARequestDimension(name: 'date'),
      ],
      metrics: [
        GARequestMetric(name: metricName),
      ],
      dimensionFilter: query is EventCountQuery
          ? GARequestFilterExpression(
              filter: GARequestFilter(
                fieldName: 'eventName',
                stringFilter: GARequestStringFilter(value: query.event.name),
              ),
            )
          : null,
    );

    final response = await _runReport(request.toJson());

    final rows = response.rows;
    if (rows == null || rows.isEmpty) {
      _log.finer('No time series data returned from Google Analytics.');
      return [];
    }

    return rows
        .map((row) {
          final dateStr = row.dimensionValues.firstOrNull?.value;
          final valueStr = row.metricValues.firstOrNull?.value;
          if (dateStr == null || valueStr == null) return null;

          return DataPoint(
            timestamp: DateTime.parse(dateStr),
            value: num.tryParse(valueStr) ?? 0.0,
          );
        })
        .whereType<DataPoint>()
        .toList();
  }

  @override
  Future<num> getMetricTotal(
    MetricQuery query,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final metricName = _getMetricName(query);
    if (metricName.startsWith('database:')) {
      throw ArgumentError.value(
        query,
        'query',
        'Database queries cannot be handled by GoogleAnalyticsDataClient.',
      );
    }

    _log.info('Fetching total for metric "$metricName" from Google Analytics.');
    final request = RunReportRequest(
      dateRanges: [
        GARequestDateRange(
          startDate: DateFormat('y-MM-dd').format(startDate),
          endDate: DateFormat('y-MM-dd').format(endDate),
        ),
      ],
      metrics: [
        GARequestMetric(name: metricName),
      ],
      dimensionFilter: query is EventCountQuery
          ? GARequestFilterExpression(
              filter: GARequestFilter(
                fieldName: 'eventName',
                stringFilter: GARequestStringFilter(value: query.event.name),
              ),
            )
          : null,
    );

    final response = await _runReport(request.toJson());

    final rows = response.rows;
    if (rows == null || rows.isEmpty) {
      _log.finer('No metric total data returned from Google Analytics.');
      return 0;
    }

    final valueStr = rows.firstOrNull?.metricValues.firstOrNull?.value;
    return num.tryParse(valueStr ?? '0') ?? 0.0;
  }

  @override
  Future<List<RankedListItem>> getRankedList(
    RankedListQuery query,
    DateTime startDate,
    DateTime endDate,
  ) async {
    const metricName = 'eventCount'; // Ranked lists are always event counts
    final dimensionName = query.dimension;

    _log.info(
      'Fetching ranked list for dimension "$dimensionName" by metric '
      '"$metricName" from Google Analytics.',
    );
    final request = RunReportRequest(
      dateRanges: [
        GARequestDateRange(
          startDate: DateFormat('y-MM-dd').format(startDate),
          endDate: DateFormat('y-MM-dd').format(endDate),
        ),
      ],
      dimensions: [
        GARequestDimension(name: 'customEvent:$dimensionName'),
      ],
      metrics: const [
        GARequestMetric(name: metricName),
      ],
      limit: query.limit,
      dimensionFilter: GARequestFilterExpression(
        filter: GARequestFilter(
          fieldName: 'eventName',
          stringFilter: GARequestStringFilter(value: query.event.name),
        ),
      ),
    );

    final response = await _runReport(request.toJson());

    final rows = response.rows;
    if (rows == null || rows.isEmpty) {
      _log.finer('No ranked list data returned from Google Analytics.');
      return [];
    }

    final rawItems = <RankedListItem>[];
    for (final row in rows) {
      final entityId = row.dimensionValues.firstOrNull?.value;
      final metricValueStr = row.metricValues.firstOrNull?.value;
      if (entityId == null || metricValueStr == null) continue;

      final metricValue = num.tryParse(metricValueStr) ?? 0;
      rawItems.add(
        RankedListItem(
          entityId: entityId,
          displayTitle: '',
          metricValue: metricValue,
        ),
      );
    }

    final headlineIds = rawItems.map((item) => item.entityId).toList();
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

  Future<RunReportResponse> _runReport(Map<String, dynamic> requestBody) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/properties/$_propertyId:runReport',
      data: requestBody,
    );
    return RunReportResponse.fromJson(response);
  }
}
