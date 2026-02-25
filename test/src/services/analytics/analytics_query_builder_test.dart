import 'package:flutter_news_app_api_server_full_source_code/src/models/models.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/analytics/analytics.dart';
import 'package:test/test.dart';

void main() {
  group('AnalyticsQueryBuilder', () {
    late AnalyticsQueryBuilder queryBuilder;
    late DateTime startDate;
    late DateTime endDate;

    setUp(() {
      queryBuilder = AnalyticsQueryBuilder();
      endDate = DateTime.utc(2024, 1, 31);
      startDate = DateTime.utc(2024, 1, 1);
    });

    test('buildPipelineForMetric returns null for unsupported metric', () {
      const query = StandardMetricQuery(metric: 'unsupported:metric');
      final pipeline = queryBuilder.buildPipelineForMetric(
        query,
        startDate,
        endDate,
      );
      expect(pipeline, isNull);
    });

    group('Categorical Queries', () {
      const query = StandardMetricQuery(
        metric: 'database:users:userTierDistribution',
      );

      test(
        'builds correct pipeline for userTierDistribution (non-time-bound)',
        () {
          final pipeline = queryBuilder.buildPipelineForMetric(
            query,
            startDate,
            endDate,
          );

          final expectedPipeline = [
            {
              r'$group': {
                '_id': r'$tier',
                'count': {r'$sum': 1},
              },
            },
            {
              r'$project': {'label': r'$_id', 'value': r'$count', '_id': 0},
            },
          ];

          expect(pipeline, equals(expectedPipeline));
        },
      );

      test('builds correct pipeline for reportsByReason (time-bound)', () {
        const query = StandardMetricQuery(
          metric: 'database:reports:byReason',
        );
        final pipeline = queryBuilder.buildPipelineForMetric(
          query,
          startDate,
          endDate,
        );

        final expectedPipeline = [
          {
            r'$match': {
              'createdAt': {
                r'$gte': startDate.toUtc().toIso8601String(),
                r'$lt': endDate.toUtc().toIso8601String(),
              },
            },
          },
          {
            r'$group': {
              '_id': r'$reason',
              'count': {r'$sum': 1},
            },
          },
          {
            r'$project': {'label': r'$_id', 'value': r'$count', '_id': 0},
          },
        ];

        expect(pipeline, equals(expectedPipeline));
      });

      test('builds correct pipeline for reactionsByType (time-bound)', () {
        const query = StandardMetricQuery(
          metric: 'database:engagements:reactionsByType',
        );
        final pipeline = queryBuilder.buildPipelineForMetric(
          query,
          startDate,
          endDate,
        );

        final expectedPipeline = [
          {
            r'$match': {
              'createdAt': {
                r'$gte': startDate.toUtc().toIso8601String(),
                r'$lt': endDate.toUtc().toIso8601String(),
              },
              'reaction': {r'$exists': true},
            },
          },
          {
            r'$group': {
              '_id': r'$reaction.reactionType',
              'count': {r'$sum': 1},
            },
          },
          {
            r'$project': {'label': r'$_id', 'value': r'$count', '_id': 0},
          },
        ];

        expect(pipeline, equals(expectedPipeline));
      });

      test('builds correct pipeline for appReviewFeedback (time-bound)', () {
        const query = StandardMetricQuery(
          metric: 'database:app_reviews:feedback',
        );
        final pipeline = queryBuilder.buildPipelineForMetric(
          query,
          startDate,
          endDate,
        );

        final expectedPipeline = [
          {
            r'$match': {
              'createdAt': {
                r'$gte': startDate.toUtc().toIso8601String(),
                r'$lt': endDate.toUtc().toIso8601String(),
              },
            },
          },
          {
            r'$group': {
              '_id': r'$feedback',
              'count': {r'$sum': 1},
            },
          },
          {
            r'$project': {'label': r'$_id', 'value': r'$count', '_id': 0},
          },
        ];

        expect(pipeline, equals(expectedPipeline));
      });

      test('builds correct pipeline for topicEngagement (time-bound)', () {
        const query = StandardMetricQuery(
          metric: 'database:headlines:topicEngagement',
        );
        final pipeline = queryBuilder.buildPipelineForMetric(
          query,
          startDate,
          endDate,
        );

        final expectedPipeline = [
          {
            r'$match': {
              'createdAt': {
                r'$gte': startDate.toUtc().toIso8601String(),
                r'$lt': endDate.toUtc().toIso8601String(),
              },
            },
          },
          {
            r'$group': {
              '_id': r'$topic.name',
              'count': {r'$sum': 1},
            },
          },
          {
            r'$project': {'label': r'$_id', 'value': r'$count', '_id': 0},
          },
        ];

        expect(pipeline, equals(expectedPipeline));
      });

      test('builds correct pipeline for viewsByTopic (time-bound)', () {
        const query = StandardMetricQuery(
          metric: 'database:headlines:viewsByTopic',
        );
        final pipeline = queryBuilder.buildPipelineForMetric(
          query,
          startDate,
          endDate,
        );

        final expectedPipeline = [
          {
            r'$match': {
              'createdAt': {
                r'$gte': startDate.toUtc().toIso8601String(),
                r'$lt': endDate.toUtc().toIso8601String(),
              },
            },
          },
          {
            r'$group': {
              '_id': r'$topic.name',
              'count': {r'$sum': 1},
            },
          },
          {
            r'$project': {'label': r'$_id', 'value': r'$count', '_id': 0},
          },
        ];

        expect(pipeline, equals(expectedPipeline));
      });

      test('builds correct pipeline for active rewards count', () {
        const query = StandardMetricQuery(
          metric: 'database:user_rewards:active_count',
        );
        final pipeline = queryBuilder.buildPipelineForMetric(
          query,
          startDate,
          endDate,
        );

        final expectedPipeline = [
          {
            r'$project': {
              'rewardsArray': {r'$objectToArray': r'$activeRewards'},
            },
          },
          {
            r'$match': {
              'rewardsArray.v': {r'$gt': endDate.toUtc().toIso8601String()},
            },
          },
          {r'$count': 'total'},
        ];

        expect(pipeline, equals(expectedPipeline));
      });

      test('builds correct pipeline for active rewards by type', () {
        const query = StandardMetricQuery(
          metric: 'database:user_rewards:active_by_type',
        );
        final pipeline = queryBuilder.buildPipelineForMetric(
          query,
          startDate,
          endDate,
        );

        // We can't strictly test the 'now' string since it changes,
        // but we can verify the structure.
        expect(pipeline, isNotNull);
        expect(pipeline!.length, equals(5));
        expect(
          pipeline[0],
          containsPair(r'$project', isA<Map<String, dynamic>>()),
        );
        expect(pipeline[1], containsPair(r'$unwind', r'$rewardsArray'));
        expect(
          pipeline[2],
          containsPair(r'$match', isA<Map<String, dynamic>>()),
        );
        expect(
          pipeline[3],
          equals({
            r'$group': {
              '_id': r'$rewardsArray.k',
              'count': {r'$sum': 1},
            },
          }),
        );
      });

      test('builds correct pipeline for media by purpose', () {
        const query = StandardMetricQuery(
          metric: 'database:media_asset:by_purpose',
        );
        final pipeline = queryBuilder.buildPipelineForMetric(
          query,
          startDate,
          endDate,
        );

        final expectedPipeline = [
          {
            r'$match': {
              'createdAt': {
                r'$gte': startDate.toUtc().toIso8601String(),
                r'$lt': endDate.toUtc().toIso8601String(),
              },
            },
          },
          {
            r'$group': {
              '_id': r'$purpose',
              'count': {r'$sum': 1},
            },
          },
          {
            r'$project': {'label': r'$_id', 'value': r'$count', '_id': 0},
          },
        ];

        expect(pipeline, equals(expectedPipeline));
      });

      test('builds correct pipeline for media status distribution', () {
        const query = StandardMetricQuery(
          metric: 'database:media_asset:status_distribution',
        );
        final pipeline = queryBuilder.buildPipelineForMetric(
          query,
          startDate,
          endDate,
        );

        final expectedPipeline = [
          {
            r'$match': {
              'createdAt': {
                r'$gte': startDate.toUtc().toIso8601String(),
                r'$lt': endDate.toUtc().toIso8601String(),
              },
            },
          },
          {
            r'$group': {
              '_id': r'$status',
              'count': {r'$sum': 1},
            },
          },
          {
            r'$project': {'label': r'$_id', 'value': r'$count', '_id': 0},
          },
        ];

        expect(pipeline, equals(expectedPipeline));
      });
    });

    group('Ranked List Queries', () {
      test('builds correct pipeline for sourcesByFollowers', () {
        const query = StandardMetricQuery(
          metric: 'database:sources:byFollowers',
        );
        final pipeline = queryBuilder.buildPipelineForMetric(
          query,
          startDate,
          endDate,
        );

        final expectedPipeline = [
          {
            r'$project': {
              'name': 1,
              'followerCount': {
                r'$size': {
                  // ignore: inference_failure_on_collection_literal
                  r'$ifNull': [r'$followerIds', []],
                },
              },
            },
          },
          {
            r'$sort': {'followerCount': -1},
          },
          {r'$limit': 5},
          {
            r'$project': {
              'entityId': r'$_id',
              'displayTitle': r'$name',
              'metricValue': r'$followerCount',
              '_id': 0,
            },
          },
        ];

        expect(pipeline, equals(expectedPipeline));
      });

      test('builds correct pipeline for topicsByFollowers', () {
        const query = StandardMetricQuery(
          metric: 'database:topics:byFollowers',
        );
        final pipeline = queryBuilder.buildPipelineForMetric(
          query,
          startDate,
          endDate,
        );

        final expectedPipeline = [
          {
            r'$project': {
              'name': 1,
              'followerCount': {
                r'$size': {
                  // ignore: inference_failure_on_collection_literal
                  r'$ifNull': [r'$followerIds', []],
                },
              },
            },
          },
          {
            r'$sort': {'followerCount': -1},
          },
          {r'$limit': 5},
          {
            r'$project': {
              'entityId': r'$_id',
              'displayTitle': r'$name',
              'metricValue': r'$followerCount',
              '_id': 0,
            },
          },
        ];

        expect(pipeline, equals(expectedPipeline));
      });
    });

    group('Complex Aggregation Queries', () {
      test('builds correct pipeline for avgReportResolutionTime', () {
        const query = StandardMetricQuery(
          metric: 'database:reports:avgResolutionTime',
        );
        final pipeline = queryBuilder.buildPipelineForMetric(
          query,
          startDate,
          endDate,
        );

        final expectedPipeline = [
          {
            r'$match': {
              'status': 'resolved',
              'updatedAt': {
                r'$gte': startDate.toUtc().toIso8601String(),
                r'$lt': endDate.toUtc().toIso8601String(),
              },
            },
          },
          {
            r'$group': {
              '_id': {
                r'$dateToString': {
                  'format': '%Y-%m-%d',
                  'date': r'$updatedAt',
                },
              },
              'avgResolutionTime': {
                r'$avg': {
                  r'$subtract': [r'$updatedAt', r'$createdAt'],
                },
              },
            },
          },
          {
            r'$project': {
              'label': r'$_id',
              'value': {
                r'$divide': [r'$avgResolutionTime', 3600000],
              },
              '_id': 0,
            },
          },
          {
            r'$sort': {'label': 1},
          },
        ];

        expect(pipeline, equals(expectedPipeline));
      });

      test('builds correct pipeline for avgUploadTime', () {
        const query = StandardMetricQuery(
          metric: 'database:media_asset:avg_upload_time',
        );
        final pipeline = queryBuilder.buildPipelineForMetric(
          query,
          startDate,
          endDate,
        );

        final expectedPipeline = [
          {
            r'$match': {
              'status': 'completed',
              'updatedAt': {
                r'$gte': startDate.toUtc().toIso8601String(),
                r'$lt': endDate.toUtc().toIso8601String(),
              },
            },
          },
          {
            r'$group': {
              '_id': null,
              'avgUploadTime': {
                r'$avg': {
                  r'$subtract': [r'$updatedAt', r'$createdAt'],
                },
              },
            },
          },
          {
            r'$project': {
              'total': {
                r'$divide': [r'$avgUploadTime', 1000],
              },
            },
          },
        ];

        expect(pipeline, equals(expectedPipeline));
      });
    });
  });
}
