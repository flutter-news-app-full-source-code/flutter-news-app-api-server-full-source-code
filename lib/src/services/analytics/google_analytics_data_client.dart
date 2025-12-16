import 'package:core/core.dart';
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
  }) : _propertyId = propertyId,
       _log = log {
    _httpClient = HttpClient(
      baseUrl: 'https://analyticsdata.googleapis.com/v1beta',
      tokenProvider: firebaseAuthenticator.getAccessToken,
      logger: _log,
    );
  }

  final String _propertyId;
  late final HttpClient _httpClient;
  final Logger _log;

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
        },
      ],
      'dimensions': [
        {'name': 'date'},
      ],
      'metrics': [
        {'name': metricName},
      ],
    });

    if (response.rows == null) return [];

    return response.rows!.map((row) {
      final dateStr = row.dimensionValues.first.value!;
      final valueStr = row.metricValues.first.value!;
      return DataPoint(
        timestamp: DateTime.parse(dateStr),
        value: num.tryParse(valueStr) ?? 0,
      );
    }).toList();
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
        },
      ],
      'metrics': [
        {'name': metricName},
      ],
    });

    if (response.rows == null || response.rows!.isEmpty) return 0;

    final valueStr = response.rows!.first.metricValues.first.value!;
    return num.tryParse(valueStr) ?? 0;
  }

  @override
  Future<List<RankedListItem>> getRankedList(
    String dimensionName,
    String metricName,
  ) async {
    // This is a placeholder. A real implementation would need to fetch data
    // from Google Analytics and likely enrich it with data from our own DB.
    _log.warning('getRankedList for Google Analytics is not implemented.');
    return [];
  }

  Future<RunReportResponse> _runReport(Map<String, dynamic> requestBody) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/properties/$_propertyId:runReport',
      data: requestBody,
    );
    return RunReportResponse.fromJson(response);
  }
}
