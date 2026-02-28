// ignore_for_file: inference_failure_on_function_invocation

import 'package:core/core.dart';

import 'package:flutter_news_app_backend_api_full_source_code/src/clients/analytics/google_analytics_data_client.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/models.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/google_auth_service.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockGoogleAuthService extends Mock implements IGoogleAuthService {}

class MockHeadlineRepository extends Mock implements DataRepository<Headline> {}

void main() {
  group('GoogleAnalyticsDataClient', () {
    late GoogleAnalyticsDataClient client;
    late MockHttpClient mockHttpClient;
    late MockGoogleAuthService mockAuthenticator;
    late MockHeadlineRepository mockHeadlineRepository;
    late DateTime startDate;
    late DateTime endDate;

    const propertyId = 'test-property-id';

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockAuthenticator = MockGoogleAuthService();
      mockHeadlineRepository = MockHeadlineRepository();
      startDate = DateTime.utc(2024, 1, 1);
      endDate = DateTime.utc(2024, 1, 7);

      client = GoogleAnalyticsDataClient(
        propertyId: propertyId,
        firebaseAuthenticator: mockAuthenticator,
        log: Logger('TestGoogleAnalyticsDataClient'),
        headlineRepository: mockHeadlineRepository,
        httpClient: mockHttpClient, // Inject the mock client
      );

      // Stub the authenticator
      when(
        () => mockAuthenticator.getAccessToken(scope: any(named: 'scope')),
      ).thenAnswer((_) async => 'test-token');

      // Register fallback values
      registerFallbackValue(Uri.parse('http://localhost'));
    });

    group('getTimeSeries', () {
      test('throws ArgumentError for database queries', () {
        const query = StandardMetricQuery(metric: 'database:someMetric');
        expect(
          () => client.getTimeSeries(query, startDate, endDate),
          throwsArgumentError,
        );
      });

      test('returns empty list for empty API response', () async {
        // ARRANGE: Mock an empty response
        final mockApiResponse = <String, dynamic>{};

        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async => mockApiResponse);

        // ACT
        final result = await client.getTimeSeries(
          const StandardMetricQuery(metric: 'activeUsers'),
          startDate,
          endDate,
        );

        // ASSERT
        expect(result, isA<List<DataPoint>>());
        expect(result, isEmpty);
      });

      test(
        'correctly parses a valid GA4 API response into DataPoints',
        () async {
          // ARRANGE: Define a realistic JSON response from the GA4 API
          final mockApiResponse = {
            'rows': [
              {
                'dimensionValues': [
                  {'value': '20240101'},
                ],
                'metricValues': [
                  {'value': '150'},
                ],
              },
              {
                'dimensionValues': [
                  {'value': '20240102'},
                ],
                'metricValues': [
                  {'value': '200'},
                ],
              },
            ],
          };

          when(
            () => mockHttpClient.post<Map<String, dynamic>>(
              any<String>(),
              data: any<dynamic>(named: 'data'),
            ),
          ).thenAnswer((_) async => mockApiResponse);

          // ACT
          final result = await client.getTimeSeries(
            const EventCountQuery(event: AnalyticsEvent.contentViewed),
            startDate,
            endDate,
          );

          // ASSERT
          expect(result, isA<List<DataPoint>>());
          expect(result, hasLength(2));
          expect(result[0].timestamp, DateTime.parse('20240101'));
          expect(result[0].value, 150);
          expect(result[1].timestamp, DateTime.parse('20240102'));
          expect(result[1].value, 200);

          verify(
            () => mockHttpClient.post<Map<String, dynamic>>(
              '/properties/$propertyId:runReport',
              data: any<dynamic>(named: 'data'),
            ),
          ).called(1);
        },
      );
    });

    group('getMetricTotal', () {
      test('returns 0 for empty API response', () async {
        // ARRANGE: Mock an empty response
        final mockApiResponse = {
          'rows': <Map<String, dynamic>>[],
        };

        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async => mockApiResponse);

        // ACT
        final result = await client.getMetricTotal(
          const EventCountQuery(event: AnalyticsEvent.contentViewed),
          startDate,
          endDate,
        );

        // ASSERT
        expect(result, 0);
      });

      test('correctly parses a valid GA4 API response for a total', () async {
        final mockApiResponse = {
          'rows': [
            {
              'metricValues': [
                {'value': '12345'},
              ],
            },
          ],
        };

        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async => mockApiResponse);

        final result = await client.getMetricTotal(
          const EventCountQuery(event: AnalyticsEvent.contentViewed),
          startDate,
          endDate,
        );

        expect(result, 12345);
      });
    });

    group('getRankedList', () {
      test('returns empty list for empty API response', () async {
        // ARRANGE: Mock an empty response
        final mockApiResponse = <String, dynamic>{};

        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            any<String>(),
            data: any<dynamic>(named: 'data'),
          ),
        ).thenAnswer((_) async => mockApiResponse);

        // ACT
        final result = await client.getRankedList(
          const RankedListQuery(
            event: AnalyticsEvent.contentViewed,
            dimension: 'contentId',
          ),
          startDate,
          endDate,
        );

        // ASSERT
        expect(result, isEmpty);
      });

      test(
        'correctly parses response and enriches with headline titles',
        () async {
          // ARRANGE: Mock API response and repository response
          final mockGaApiResponse = {
            'rows': [
              {
                'dimensionValues': [
                  {'value': 'headline-1'},
                ],
                'metricValues': [
                  {'value': '99'},
                ],
              },
              {
                'dimensionValues': [
                  {'value': 'headline-2'},
                ],
                'metricValues': [
                  {'value': '88'},
                ],
              },
            ],
          };

          final mockHeadlines = PaginatedResponse<Headline>(
            items: [
              // Only return one headline to test enrichment and default case
              Headline(
                id: 'headline-1',
                title: const {SupportedLanguage.en: 'Test Headline 1'},
                url: '',
                imageUrl: '',
                source: Source(
                  id: 's1',
                  name: const {SupportedLanguage.en: 's'},
                  description: const {SupportedLanguage.en: ''},
                  url: '',
                  logoUrl: '',
                  sourceType: SourceType.aggregator,
                  language: SupportedLanguage.en,
                  headquarters: const Country(
                    isoCode: 'US',
                    name: {SupportedLanguage.en: 'USA'},
                    flagUrl: '',
                    id: 'c1',
                  ),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  status: ContentStatus.active,
                ),
                eventCountry: const Country(
                  isoCode: 'US',
                  name: {SupportedLanguage.en: 'USA'},
                  flagUrl: '',
                  id: 'c1',
                ),
                topic: Topic(
                  id: 't1',
                  name: const {SupportedLanguage.en: 't'},
                  description: const {SupportedLanguage.en: ''},
                  iconUrl: '',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  status: ContentStatus.active,
                ),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                status: ContentStatus.active,
                isBreaking: false,
              ),
            ],
            cursor: null,
            hasMore: false,
          );

          when(
            () => mockHttpClient.post<Map<String, dynamic>>(
              any(),
              data: any<dynamic>(named: 'data'),
            ),
          ).thenAnswer((_) async => mockGaApiResponse);

          when(
            () => mockHeadlineRepository.readAll(
              filter: any<Map<String, dynamic>>(named: 'filter'),
            ),
          ).thenAnswer((_) async => mockHeadlines);

          // ACT
          final result = await client.getRankedList(
            const RankedListQuery(
              event: AnalyticsEvent.contentViewed,
              dimension: 'contentId',
            ),
            startDate,
            endDate,
          );

          // ASSERT
          expect(result, hasLength(2));
          expect(result[0].entityId, 'headline-1');
          expect(
            result[0].displayTitle[SupportedLanguage.en],
            'Test Headline 1',
          );
          expect(result[0].metricValue, 99);

          expect(result[1].entityId, 'headline-2');
          expect(
            result[1].displayTitle[SupportedLanguage.en],
            'Unknown Headline',
          );
          expect(result[1].metricValue, 88);

          verify(
            () => mockHeadlineRepository.readAll(
              filter: {
                '_id': {
                  r'$in': ['headline-1', 'headline-2'],
                },
              },
            ),
          ).called(1);
        },
      );
    });

    group('getTimeSeriesBatch', () {
      test('correctly parses batched response with multiple ranges', () async {
        const range1 = GARequestDateRange(
          startDate: '2024-01-01',
          endDate: '2024-01-07',
        );
        const range2 = GARequestDateRange(
          startDate: '2024-01-08',
          endDate: '2024-01-14',
        );

        final mockApiResponse = {
          'rows': [
            {
              'dimensionValues': [
                {'value': 'date_range_0'},
                {'value': '20240101'},
              ],
              'metricValues': [
                {'value': '10'},
              ],
            },
            {
              'dimensionValues': [
                {'value': 'date_range_1'},
                {'value': '20240108'},
              ],
              'metricValues': [
                {'value': '20'},
              ],
            },
          ],
        };

        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => mockApiResponse);

        final result = await client.getTimeSeriesBatch(
          const EventCountQuery(event: AnalyticsEvent.contentViewed),
          [range1, range2],
        );

        expect(result, hasLength(2));
        expect(result[range1], hasLength(1));
        expect(result[range1]!.first.value, 10);
        expect(result[range2], hasLength(1));
        expect(result[range2]!.first.value, 20);
      });

      test('handles empty response gracefully', () async {
        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => {});

        final result = await client.getTimeSeriesBatch(
          const EventCountQuery(event: AnalyticsEvent.contentViewed),
          [
            const GARequestDateRange(
              startDate: '2024-01-01',
              endDate: '2024-01-02',
            ),
          ],
        );

        expect(result, isEmpty);
      });
    });

    group('getMetricTotalsBatch', () {
      test('correctly parses batched totals', () async {
        const range1 = GARequestDateRange(
          startDate: '2024-01-01',
          endDate: '2024-01-07',
        );
        const range2 = GARequestDateRange(
          startDate: '2024-01-08',
          endDate: '2024-01-14',
        );

        final mockApiResponse = {
          'rows': [
            {
              'dimensionValues': [
                {'value': 'date_range_0'},
              ],
              'metricValues': [
                {'value': '100'},
              ],
            },
            {
              'dimensionValues': [
                {'value': 'date_range_1'},
              ],
              'metricValues': [
                {'value': '200'},
              ],
            },
          ],
        };

        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => mockApiResponse);

        final result = await client.getMetricTotalsBatch(
          const EventCountQuery(event: AnalyticsEvent.contentViewed),
          [range1, range2],
        );

        expect(result[range1], 100);
        expect(result[range2], 200);
      });
    });
  });
}
