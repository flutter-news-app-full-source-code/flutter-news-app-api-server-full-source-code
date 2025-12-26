import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/clients.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockHeadlineRepository extends Mock implements DataRepository<Headline> {}

void main() {
  group('MixpanelDataClient', () {
    late MixpanelDataClient mixpanelClient;
    late MockHttpClient mockHttpClient;
    late MockHeadlineRepository mockHeadlineRepository;
    late DateTime startDate;
    late DateTime endDate;

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockHeadlineRepository = MockHeadlineRepository();
      mixpanelClient = MixpanelDataClient(
        projectId: 'test-project-id',
        serviceAccountUsername: 'test-user',
        serviceAccountSecret: 'test-secret',
        log: Logger('TestMixpanelClient'),
        headlineRepository: mockHeadlineRepository,
        httpClient: mockHttpClient, // Inject mock client
      );

      startDate = DateTime.utc(2024, 1, 1);
      endDate = DateTime.utc(2024, 1, 7);
    });

    group('getTimeSeries', () {
      test('throws ArgumentError for database queries', () {
        const query = StandardMetricQuery(metric: 'database:someMetric');
        expect(
          () => mixpanelClient.getTimeSeries(query, startDate, endDate),
          throwsArgumentError,
        );
      });

      test('returns empty list for empty API response', () async {
        // ARRANGE
        const query = EventCountQuery(event: AnalyticsEvent.contentViewed);
        final mockResponse = {
          'data': {
            'series': <String>[],
            'values': <String, dynamic>{},
          },
        };

        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => mockResponse);

        // ACT
        final result = await mixpanelClient.getTimeSeries(
          query,
          startDate,
          endDate,
        );

        // ASSERT
        expect(result, isA<List<DataPoint>>());
        expect(result, isEmpty);
      });

      test('correctly fetches time series for activeUsers metric', () async {
        // ARRANGE
        const query = StandardMetricQuery(metric: 'activeUsers');
        // Mixpanel uses a special metric name for active users
        const expectedEventName = r'$active';

        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer(
          (_) async => {
            'data': {'series': <String>[], 'values': <String, dynamic>{}},
          },
        );

        // ACT
        await mixpanelClient.getTimeSeries(query, startDate, endDate);

        // ASSERT: Verify the correct event name was used in the request
        final captured = verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          ),
        ).captured;

        final request = captured.first as Map<String, dynamic>;
        expect(request['event'], expectedEventName);
      });

      test('correctly fetches and parses time series data', () async {
        const query = EventCountQuery(event: AnalyticsEvent.contentViewed);
        final mockResponse = {
          'data': {
            'series': ['2024-01-01', '2024-01-02'],
            'values': {
              'contentViewed': [100, 150],
            },
          },
        };

        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            '/segmentation',
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final result = await mixpanelClient.getTimeSeries(
          query,
          startDate,
          endDate,
        );

        expect(result, isA<List<DataPoint>>());
        expect(result.length, 2);
        expect(result[0].timestamp, DateTime.parse('2024-01-01'));
        expect(result[0].value, 100);
        expect(result[1].timestamp, DateTime.parse('2024-01-02'));
        expect(result[1].value, 150);

        const expectedRequest = MixpanelSegmentationRequest(
          projectId: 'test-project-id',
          event: 'contentViewed',
          fromDate: '2024-01-01',
          toDate: '2024-01-07',
          unit: MixpanelTimeUnit.day,
        );

        verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
            '/segmentation',
            queryParameters: expectedRequest.toJson(),
          ),
        ).called(1);
      });
    });

    group('getMetricTotal', () {
      test('returns 0 for empty API response', () async {
        // ARRANGE
        const query = EventCountQuery(event: AnalyticsEvent.contentViewed);
        final mockResponse = {
          'data': {
            'series': <String>[],
            'values': <String, dynamic>{},
          },
        };

        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => mockResponse);

        // ACT
        final total = await mixpanelClient.getMetricTotal(
          query,
          startDate,
          endDate,
        );

        // ASSERT
        expect(total, 0);
      });

      test('correctly calculates total from time series', () async {
        const query = EventCountQuery(event: AnalyticsEvent.contentViewed);
        final mockResponse = {
          'data': {
            'series': ['2024-01-01', '2024-01-02'],
            'values': {
              'contentViewed': [100, 150],
            },
          },
        };

        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            '/segmentation',
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final total = await mixpanelClient.getMetricTotal(
          query,
          startDate,
          endDate,
        );

        expect(total, 250);
      });
    });

    group('getRankedList', () {
      test('returns empty list for empty API response', () async {
        // ARRANGE
        const query = RankedListQuery(
          event: AnalyticsEvent.contentViewed,
          dimension: 'contentId',
        );
        final mockMixpanelResponse = <String, dynamic>{};

        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => mockMixpanelResponse);

        // ACT
        final result = await mixpanelClient.getRankedList(
          query,
          startDate,
          endDate,
        );

        // ASSERT
        expect(result, isA<List<RankedListItem>>());
        expect(result, isEmpty);
      });

      test('correctly fetches and enriches ranked list data', () async {
        const query = RankedListQuery(
          event: AnalyticsEvent.contentViewed,
          dimension: 'contentId',
          limit: 2,
        );
        final mockMixpanelResponse = {
          'headline1': {'count': 50},
          'headline2': {'count': 40},
        };

        final mockHeadlines = PaginatedResponse<Headline>(
          items: [
            Headline(
              id: 'headline1',
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
          () => mockHttpClient.get<Map<String, dynamic>>(
            '/events/properties/top',
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => mockMixpanelResponse);

        when(
          () => mockHeadlineRepository.readAll(
            filter: any(named: 'filter'),
          ),
        ).thenAnswer((_) async => mockHeadlines);

        final result = await mixpanelClient.getRankedList(
          query,
          startDate,
          endDate,
        );

        expect(result, isA<List<RankedListItem>>());
        expect(result.length, 2);
        expect(result[0].entityId, 'headline1');
        expect(result[0].displayTitle, 'Test Headline 1');
        expect(result[0].metricValue, 50);
        expect(result[1].entityId, 'headline2');
        // This one wasn't in the mock repo response, so it gets a default title
        expect(result[1].displayTitle, 'Unknown Headline');
        expect(result[1].metricValue, 40);

        const expectedRequest = MixpanelTopEventsRequest(
          projectId: 'test-project-id',
          event: 'contentViewed',
          name: 'contentId',
          fromDate: '2024-01-01',
          toDate: '2024-01-07',
          limit: 2,
        );

        verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
            '/events/properties/top',
            queryParameters: expectedRequest.toJson(),
          ),
        ).called(1);

        verify(
          () => mockHeadlineRepository.readAll(
            filter: {
              '_id': {
                r'$in': ['headline1', 'headline2'],
              },
            },
          ),
        ).called(1);
      });
    });
  });
}
