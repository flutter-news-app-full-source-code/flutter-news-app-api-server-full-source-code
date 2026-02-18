import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import '../../../../../../routes/api/v1/webhooks/storage/s3-notifications.dart'
    as route;
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/idempotency_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/media_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/util/sns_message_handler.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockRequestContext extends Mock implements RequestContext {}

class MockRequest extends Mock implements Request {}

class MockIdempotencyService extends Mock implements IdempotencyService {}

class MockMediaService extends Mock implements MediaService {}

class MockDataRepository<T> extends Mock implements DataRepository<T> {}

class MockSnsMessageHandler extends Mock implements SnsMessageHandler {}

void main() {
  late MockRequestContext mockContext;
  late MockRequest mockRequest;
  late MockIdempotencyService mockIdempotencyService;
  late MockMediaService mockMediaService;
  late MockDataRepository<MediaAsset> mockMediaAssetRepo;
  late MockSnsMessageHandler mockSnsMessageHandler;

  setUp(() {
    mockContext = MockRequestContext();
    mockRequest = MockRequest();
    mockIdempotencyService = MockIdempotencyService();
    mockMediaService = MockMediaService();
    mockMediaAssetRepo = MockDataRepository<MediaAsset>();
    mockSnsMessageHandler = MockSnsMessageHandler();

    when(() => mockContext.request).thenReturn(mockRequest);
    when(() => mockRequest.method).thenReturn(HttpMethod.post);

    when(
      () => mockContext.read<IdempotencyService>(),
    ).thenReturn(mockIdempotencyService);
    when(() => mockContext.read<MediaService>()).thenReturn(mockMediaService);
    when(
      () => mockContext.read<DataRepository<MediaAsset>>(),
    ).thenReturn(mockMediaAssetRepo);
    when(
      () => mockContext.read<SnsMessageHandler>(),
    ).thenReturn(mockSnsMessageHandler);

    // Default environment
    EnvironmentConfig.setOverride('AWS_BUCKET_NAME', 'test-bucket');
    EnvironmentConfig.setOverride('AWS_REGION', 'us-east-1');

    registerFallbackValue(
      MediaAsset(
        id: 'fallback',
        userId: 'user',
        purpose: MediaAssetPurpose.userProfilePhoto,
        status: MediaAssetStatus.pendingUpload,
        storagePath: 'path',
        contentType: 'image/jpeg',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    registerFallbackValue(const PaginationOptions());
  });

  tearDown(() {
    EnvironmentConfig.setOverride('AWS_BUCKET_NAME', null);
    EnvironmentConfig.setOverride('AWS_REGION', null);
  });

  group('S3 Notifications Webhook', () {
    test('returns 405 if method is not POST', () async {
      when(() => mockRequest.method).thenReturn(HttpMethod.get);
      final response = await route.onRequest(mockContext);
      expect(response.statusCode, HttpStatus.methodNotAllowed);
    });

    test('handles SNS SubscriptionConfirmation', () async {
      final payload = {
        'Type': 'SubscriptionConfirmation',
        'MessageId': 'msg-123',
        'SubscribeURL': 'https://sns.aws.com/confirm',
      };
      when(
        () => mockRequest.body(),
      ).thenAnswer((_) async => jsonEncode(payload));
      when(
        () => mockSnsMessageHandler.confirmSubscription(any()),
      ).thenAnswer((_) async {});

      final response = await route.onRequest(mockContext);

      expect(response.statusCode, HttpStatus.ok);
      verify(
        () => mockSnsMessageHandler.confirmSubscription(
          'https://sns.aws.com/confirm',
        ),
      ).called(1);
    });

    test('processes S3 ObjectCreated event (Direct)', () async {
      final payload = {
        'Records': [
          {
            'eventName': 'ObjectCreated:Put',
            's3': {
              'object': {'key': 'uploads/image.jpg'},
            },
          },
        ],
      };
      when(
        () => mockRequest.body(),
      ).thenAnswer((_) async => jsonEncode(payload));

      // Idempotency check
      when(
        () => mockIdempotencyService.isEventProcessed(any(), scope: 's3'),
      ).thenAnswer((_) async => false);
      when(
        () => mockIdempotencyService.recordEvent(any(), scope: 's3'),
      ).thenAnswer((_) async {});

      // Asset lookup
      final asset = MediaAsset(
        id: 'asset1',
        userId: 'u1',
        purpose: MediaAssetPurpose.userProfilePhoto,
        status: MediaAssetStatus.pendingUpload,
        storagePath: 'uploads/image.jpg',
        contentType: 'image/jpeg',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      when(
        () => mockMediaAssetRepo.readAll(
          filter: {'storagePath': 'uploads/image.jpg'},
          pagination: any(
            named: 'pagination',
          ), // Removed const from PaginationOptions in matcher if present, or just rely on type
        ),
      ).thenAnswer(
        (_) async =>
            PaginatedResponse(items: [asset], cursor: null, hasMore: false),
      );

      // Media Service
      when(
        () => mockMediaService.finalizeUpload(
          mediaAsset: asset,
          publicUrl: any(named: 'publicUrl'),
        ),
      ).thenAnswer((_) async {});

      final response = await route.onRequest(mockContext);

      expect(response.statusCode, HttpStatus.noContent);
      verify(
        () => mockMediaService.finalizeUpload(
          mediaAsset: asset,
          publicUrl:
              'https://test-bucket.s3.us-east-1.amazonaws.com/uploads/image.jpg',
        ),
      ).called(1);
      verify(
        () => mockIdempotencyService.recordEvent(
          'ObjectCreated:Put_uploads/image.jpg',
          scope: 's3',
        ),
      ).called(1);
    });

    test('processes S3 ObjectCreated event (SNS Wrapped)', () async {
      final s3Event = {
        'Records': [
          {
            'eventName': 'ObjectCreated:Put',
            's3': {
              'object': {'key': 'uploads/image.jpg'},
            },
          },
        ],
      };
      final snsPayload = {
        'Type': 'Notification',
        'MessageId': 'msg-123',
        'Message': jsonEncode(s3Event),
      };
      when(
        () => mockRequest.body(),
      ).thenAnswer((_) async => jsonEncode(snsPayload));

      // Mocks same as above...
      when(
        () => mockIdempotencyService.isEventProcessed(any(), scope: 's3'),
      ).thenAnswer((_) async => false);
      when(
        () => mockIdempotencyService.recordEvent(any(), scope: 's3'),
      ).thenAnswer((_) async {});

      final asset = MediaAsset(
        id: 'asset1',
        userId: 'u1',
        purpose: MediaAssetPurpose.userProfilePhoto,
        status: MediaAssetStatus.pendingUpload,
        storagePath: 'uploads/image.jpg',
        contentType: 'image/jpeg',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      when(
        () => mockMediaAssetRepo.readAll(
          filter: any(named: 'filter'),
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer(
        (_) async =>
            PaginatedResponse(items: [asset], cursor: null, hasMore: false),
      );
      when(
        () => mockMediaService.finalizeUpload(
          mediaAsset: any(named: 'mediaAsset'),
          publicUrl: any(named: 'publicUrl'),
        ),
      ).thenAnswer((_) async {});

      final response = await route.onRequest(mockContext);
      expect(response.statusCode, HttpStatus.noContent);
    });
  });
}
