import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/analytics/analytics_query.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/analytics/analytics.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/google_auth_service.dart';
import 'package:http_client/http_client.dart';
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
                title: 'Test Headline 1',
                url: '',
                imageUrl: '',
                source: Source(
                  id: 's1',
                  name: 's',
                  description: '',
                  url: '',
                  logoUrl: '',
                  sourceType: SourceType.aggregator,
                  language: Language(
                    id: 'l1',
                    code: 'en',
                    name: 'English',
                    nativeName: 'English',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    status: ContentStatus.active,
                  ),
                  headquarters: Country(
                    isoCode: 'US',
                    name: 'USA',
                    flagUrl: '',
                    id: 'c1',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    status: ContentStatus.active,
                  ),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  status: ContentStatus.active,
                ),
                eventCountry: Country(
                  isoCode: 'US',
                  name: 'USA',
                  flagUrl: '',
                  id: 'c1',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  status: ContentStatus.active,
                ),
                topic: Topic(
                  id: 't1',
                  name: 't',
                  description: '',
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
          expect(result[0].displayTitle, 'Test Headline 1');
          expect(result[0].metricValue, 99);

          expect(result[1].entityId, 'headline-2');
          expect(result[1].displayTitle, 'Unknown Headline');
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
  });
}
