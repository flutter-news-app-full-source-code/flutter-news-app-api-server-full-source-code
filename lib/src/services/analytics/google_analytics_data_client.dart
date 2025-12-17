import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/analytics/analytics.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/firebase_authenticator.dart';
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
    required IFirebaseAuthenticator firebaseAuthenticator,
    required Logger log,
    required DataRepository<Headline> headlineRepository,
  })  : _propertyId = propertyId,
        _log = log,
        _headlineRepository = headlineRepository {
    _httpClient = HttpClient(
      baseUrl: 'https://analyticsdata.googleapis.com/v1beta',
      tokenProvider: firebaseAuthenticator.getAccessToken,
      logger: _log,
    );
  }

  final String _propertyId;
  late final HttpClient _httpClient;
  final Logger _log;
  final DataRepository<Headline> _headlineRepository;

  @override
  Future<List<DataPoint>> getTimeSeries(
    String metricName,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _log.info(
      'Fetching time series for metric "$metricName" from Google Analytics.',
    );
    final response = await _runReport({
      'dateRanges': [
        {
          'startDate': DateFormat('yyyy-MM-dd').format(startDate),
          'endDate': DateFormat('yyyy-MM-dd').format(endDate),
        }
      ],
      'dimensions': [
        {'name': 'date'}
      ],
      'metrics': [
        {'name': metricName}
      ],
    });

    final rows = response.rows;
    if (rows == null || rows.isEmpty) {
      _log.finer('No time series data returned from Google Analytics.');
      return [];
    }

    return rows.map((row) {
      final dateStr = row.dimensionValues.first.value;
      final valueStr = row.metricValues.first.value;
      if (dateStr == null || valueStr == null) return null;

      return DataPoint(
        timestamp: DateTime.parse(dateStr),
        value: num.tryParse(valueStr) ?? 0.0,
      );
    }).whereType<DataPoint>().toList();
  }

  @override
  Future<num> getMetricTotal(
    String metricName,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _log.info('Fetching total for metric "$metricName" from Google Analytics.');
    final response = await _runReport({
      'dateRanges': [
        {
          'startDate': DateFormat('yyyy-MM-dd').format(startDate),
          'endDate': DateFormat('yyyy-MM-dd').format(endDate),
        }
      ],
      'metrics': [
        {'name': metricName}
      ],
    });

    final rows = response.rows;
    if (rows == null || rows.isEmpty) {
      _log.finer('No metric total data returned from Google Analytics.');
      return 0;
    }

    final valueStr = rows.first.metricValues.first.value;
    return num.tryParse(valueStr ?? '0') ?? 0.0;
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
      '"$metricName" from Google Analytics.',
    );
    final response = await _runReport({
      'dateRanges': [
        {
          'startDate': DateFormat('yyyy-MM-dd').format(startDate),
          'endDate': DateFormat('yyyy-MM-dd').format(endDate),
        }
      ],
      'dimensions': [
        {'name': dimensionName}
      ],
      'metrics': [
        {'name': metricName}
      ],
      'limit': limit,
    });

    final rows = response.rows;
    if (rows == null || rows.isEmpty) {
      _log.finer('No ranked list data returned from Google Analytics.');
      return [];
    }

    final items = <RankedListItem>[];
    for (final row in rows) {
      final entityId = row.dimensionValues.first.value;
      final metricValueStr = row.metricValues.first.value;
      if (entityId == null || metricValueStr == null) continue;

      final metricValue = num.tryParse(metricValueStr) ?? 0;
      items.add(
        RankedListItem(
          entityId: entityId,
          displayTitle: '',
          metricValue: metricValue,
        ),
      );
    }
    return items;
  }

  Future<RunReportResponse> _runReport(Map<String, dynamic> requestBody) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/properties/$_propertyId:runReport',
      data: requestBody,
    );
    return RunReportResponse.fromJson(response);
  }
}
