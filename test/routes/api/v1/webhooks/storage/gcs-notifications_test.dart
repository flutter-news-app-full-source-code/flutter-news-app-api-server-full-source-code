import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../../routes/api/v1/webhooks/storage/gcs-notifications.dart';
import '../../../../../src/helpers/test_helpers.dart';

void main() {
  group('POST /webhooks/storage/gcs-notifications', () {
    late MockIdempotencyService mockIdempotencyService;
    late MockMediaAssetRepository mockMediaAssetRepository;
    late MockUserRepository mockUserRepository;
    late MockStorageService mockStorageService;
    late MockHeadlineRepository mockHeadlineRepository;
    late MockTopicRepository mockTopicRepository;
    late MockSourceRepository mockSourceRepository;

    setUpAll(() {
      registerSharedFallbackValues();
      EnvironmentConfig.setOverride('GCS_BUCKET_NAME', 'test-bucket');
    });

    setUp(() {
      mockIdempotencyService = MockIdempotencyService();
      mockMediaAssetRepository = MockMediaAssetRepository();
      mockUserRepository = MockUserRepository();
      mockHeadlineRepository = MockHeadlineRepository();
      mockStorageService = MockStorageService();
      mockTopicRepository = MockTopicRepository();
      mockSourceRepository = MockSourceRepository();

      when(
        () => mockIdempotencyService.isEventProcessed(any()),
      ).thenAnswer((_) async => false);
      when(
        () => mockIdempotencyService.recordEvent(any()),
      ).thenAnswer((_) async => Future.value());
      when(
        () => mockStorageService.deleteObject(
          storagePath: any(named: 'storagePath'),
        ),
      ).thenAnswer((_) async => Future.value());
      when(
        () => mockMediaAssetRepository.delete(id: any(named: 'id')),
      ).thenAnswer((_) async => Future.value());
      when(
        () => mockUserRepository.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      ).thenAnswer((inv) async => inv.namedArguments[#item] as User);
      when(
        () => mockMediaAssetRepository.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      ).thenAnswer((inv) async => inv.namedArguments[#item] as MediaAsset);
      when(
        () => mockHeadlineRepository.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      ).thenAnswer((inv) async => inv.namedArguments[#item] as Headline);
    });

    test('returns 405 for non-POST methods', () async {
      final context = createMockRequestContext(method: HttpMethod.get);
      final response = await onRequest(context);
      expect(response.statusCode, HttpStatus.methodNotAllowed);
    });

    test('returns 200 OK if event is already processed', () async {
      when(
        () => mockIdempotencyService.isEventProcessed(any()),
      ).thenAnswer((_) async => true);

      final context = createMockRequestContext(
        method: HttpMethod.post,
        body: createGcsNotificationPayload(
          'msg-123',
          'finalize',
          'path',
        ),
        idempotencyService: mockIdempotencyService,
        mediaAssetRepository: mockMediaAssetRepository,
        userRepository: mockUserRepository,
        headlineRepository: mockHeadlineRepository,
        storageService: mockStorageService,
        topicRepository: mockTopicRepository,
        sourceRepository: mockSourceRepository,
      );

      final response = await onRequest(context);
      expect(response.statusCode, HttpStatus.ok);
      verify(
        () => mockIdempotencyService.isEventProcessed('msg-123'),
      ).called(1);
      verifyNever(
        () => mockMediaAssetRepository.readAll(filter: any(named: 'filter')),
      );
    });

    test('returns 200 OK if media asset is not found', () async {
      when(
        () => mockMediaAssetRepository.readAll(
          filter: any(named: 'filter'),
          pagination: any(named: 'pagination'),
        ),
      ).thenAnswer(
        (_) async => const PaginatedResponse(
          items: [],
          cursor: null,
          hasMore: false,
        ),
      );

      final context = createMockRequestContext(
        method: HttpMethod.post,
        body: createGcsNotificationPayload(
          'msg-123',
          'finalize',
          'path',
        ),
        idempotencyService: mockIdempotencyService,
        mediaAssetRepository: mockMediaAssetRepository,
        userRepository: mockUserRepository,
        headlineRepository: mockHeadlineRepository,
        storageService: mockStorageService,
        topicRepository: mockTopicRepository,
        sourceRepository: mockSourceRepository,
      );

      final response = await onRequest(context);
      expect(response.statusCode, HttpStatus.ok);
    });

    group('OBJECT_FINALIZE', () {
      test(
        'updates asset status and user photoUrl on userProfilePhoto finalize',
        () async {
          final oldAsset = createTestMediaAsset(
            id: 'old-asset-id',
            storagePath: 'old/path.jpg',
            publicUrl:
                'https://storage.googleapis.com/test-bucket/old/path.jpg',
          );
          final user = createTestUser(photoUrl: oldAsset.publicUrl);
          final newAsset = createTestMediaAsset(
            purpose: MediaAssetPurpose.userProfilePhoto,
            userId: user.id,
          );

          when(
            () => mockMediaAssetRepository.readAll(
              filter: {'storagePath': newAsset.storagePath},
              pagination: any(named: 'pagination'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [newAsset],
              cursor: null,
              hasMore: false,
            ),
          );
          when(
            () => mockUserRepository.readAll(
              filter: any(
                named: 'filter',
                that: predicate<Map<String, Object?>>(
                  (f) => f['mediaAssetId'] == newAsset.id,
                ),
              ),
            ),
          ).thenAnswer(
            (_) async =>
                PaginatedResponse(items: [user], cursor: null, hasMore: false),
          );
          when(
            () => mockMediaAssetRepository.readAll(
              filter: {'storagePath': oldAsset.storagePath},
              pagination: any(named: 'pagination'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [oldAsset],
              cursor: null,
              hasMore: false,
            ),
          );
          when(
            () => mockMediaAssetRepository.readAll(
              filter: {'publicUrl': oldAsset.publicUrl},
              pagination: any(named: 'pagination'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [oldAsset],
              cursor: null,
              hasMore: false,
            ),
          );

          final context = createMockRequestContext(
            method: HttpMethod.post,
            body: createGcsNotificationPayload(
              'msg-123',
              'OBJECT_FINALIZE',
              newAsset.storagePath,
            ),
            idempotencyService: mockIdempotencyService,
            mediaAssetRepository: mockMediaAssetRepository,
            userRepository: mockUserRepository,
            headlineRepository: mockHeadlineRepository,
            storageService: mockStorageService,
            topicRepository: mockTopicRepository,
            sourceRepository: mockSourceRepository,
          );

          final response = await onRequest(context);
          expect(response.statusCode, HttpStatus.noContent);

          // Allow unawaited fire-and-forget cleanup tasks to complete.
          // ignore: inference_failure_on_instance_creation
          await Future.delayed(const Duration(milliseconds: 100));

          // Verify cleanup of old asset
          verify(
            () => mockStorageService.deleteObject(
              storagePath: oldAsset.storagePath,
            ),
          ).called(1);
          verify(
            () => mockMediaAssetRepository.delete(id: oldAsset.id),
          ).called(1);

          // Verify user update
          final capturedUser =
              verify(
                    () => mockUserRepository.update(
                      id: user.id,
                      item: captureAny(named: 'item'),
                    ),
                  ).captured.single
                  as User;
          expect(
            capturedUser.photoUrl,
            'https://storage.googleapis.com/test-bucket/${newAsset.storagePath}',
          );

          // Verify asset update
          final capturedAsset =
              verify(
                    () => mockMediaAssetRepository.update(
                      id: newAsset.id,
                      item: captureAny(named: 'item'),
                    ),
                  ).captured.single
                  as MediaAsset;
          expect(capturedAsset.status, MediaAssetStatus.completed);
          expect(capturedAsset.associatedEntityId, user.id);
          expect(capturedAsset.associatedEntityType, MediaAssetEntityType.user);
          expect(capturedAsset.publicUrl, isNotNull);

          // Verify idempotency
          verify(() => mockIdempotencyService.recordEvent('msg-123')).called(1);
        },
      );

      test(
        'updates asset status and headline imageUrl on headlineImage finalize',
        () async {
          final oldAsset = createTestMediaAsset(
            id: 'old-asset-id',
            storagePath: 'old/path.jpg',
            publicUrl:
                'https://storage.googleapis.com/test-bucket/old/path.jpg',
          );
          final headline = createTestHeadline(imageUrl: oldAsset.publicUrl);
          final asset = createTestMediaAsset(
            purpose: MediaAssetPurpose.headlineImage,
            userId: 'admin-id',
          );
          when(
            () => mockHeadlineRepository.update(
              id: any(named: 'id'),
              item: any(named: 'item'),
            ),
          ).thenAnswer((inv) async => inv.namedArguments[#item] as Headline);

          when(
            () => mockMediaAssetRepository.readAll(
              filter: {'storagePath': asset.storagePath},
              pagination: any(named: 'pagination'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [asset],
              cursor: null,
              hasMore: false,
            ),
          );
          when(
            () => mockHeadlineRepository.readAll(
              filter: any(
                named: 'filter',
                that: predicate<Map<String, Object?>>(
                  (f) => f['mediaAssetId'] == asset.id,
                ),
              ),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [headline],
              cursor: null,
              hasMore: false,
            ),
          );
          when(
            () => mockMediaAssetRepository.readAll(
              filter: {'storagePath': oldAsset.storagePath},
              pagination: any(named: 'pagination'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [oldAsset],
              cursor: null,
              hasMore: false,
            ),
          );
          when(
            () => mockMediaAssetRepository.readAll(
              filter: {'publicUrl': oldAsset.publicUrl},
              pagination: any(named: 'pagination'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [oldAsset],
              cursor: null,
              hasMore: false,
            ),
          );

          final context = createMockRequestContext(
            method: HttpMethod.post,
            body: createGcsNotificationPayload(
              'msg-123',
              'OBJECT_FINALIZE',
              asset.storagePath,
            ),
            idempotencyService: mockIdempotencyService,
            mediaAssetRepository: mockMediaAssetRepository,
            headlineRepository: mockHeadlineRepository,
            userRepository: mockUserRepository,
            storageService: mockStorageService,
            topicRepository: mockTopicRepository,
            sourceRepository: mockSourceRepository,
          );

          final response = await onRequest(context);
          expect(response.statusCode, HttpStatus.noContent);

          // Allow unawaited fire-and-forget cleanup tasks to complete.
          // ignore: inference_failure_on_instance_creation
          await Future.delayed(const Duration(milliseconds: 100));

          // Verify cleanup of old asset
          verify(
            () => mockStorageService.deleteObject(
              storagePath: oldAsset.storagePath,
            ),
          ).called(1);
          verify(
            () => mockMediaAssetRepository.delete(id: oldAsset.id),
          ).called(1);

          final capturedHeadline =
              verify(
                    () => mockHeadlineRepository.update(
                      id: any(named: 'id'),
                      item: captureAny(named: 'item'),
                    ),
                  ).captured.single
                  as Headline;
          expect(
            capturedHeadline.imageUrl,
            'https://storage.googleapis.com/test-bucket/${asset.storagePath}',
          );
          expect(capturedHeadline.mediaAssetId, isNull);

          final capturedAsset =
              verify(
                    () => mockMediaAssetRepository.update(
                      id: asset.id,
                      item: captureAny(named: 'item'),
                    ),
                  ).captured.single
                  as MediaAsset;
          expect(capturedAsset.status, MediaAssetStatus.completed);
          expect(capturedAsset.associatedEntityId, headline.id);
          expect(
            capturedAsset.associatedEntityType,
            MediaAssetEntityType.headline,
          );
          expect(capturedAsset.publicUrl, isNotNull);

          verify(() => mockIdempotencyService.recordEvent('msg-123')).called(1);
        },
      );
    });

    group('OBJECT_DELETE', () {
      test(
        'deletes asset record and nullifies user photoUrl on userProfilePhoto delete',
        () async {
          const publicUrl = 'http://public/url';
          final asset = createTestMediaAsset(
            purpose: MediaAssetPurpose.userProfilePhoto,
            publicUrl: publicUrl,
            associatedEntityId: 'user-id',
            associatedEntityType: MediaAssetEntityType.user,
          );
          final user = createTestUser(
            id: asset.userId,
            photoUrl: asset.publicUrl,
          );

          when(
            () => mockMediaAssetRepository.readAll(
              filter: {'storagePath': asset.storagePath},
              pagination: any(named: 'pagination'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [asset],
              cursor: null,
              hasMore: false,
            ),
          );
          when(
            () => mockUserRepository.read(id: user.id),
          ).thenAnswer((_) async => user);

          final context = createMockRequestContext(
            method: HttpMethod.post,
            body: createGcsNotificationPayload(
              'msg-123',
              'OBJECT_DELETE',
              asset.storagePath,
            ),
            idempotencyService: mockIdempotencyService,
            mediaAssetRepository: mockMediaAssetRepository,
            userRepository: mockUserRepository,
            headlineRepository: mockHeadlineRepository,
            storageService: mockStorageService,
            topicRepository: mockTopicRepository,
            sourceRepository: mockSourceRepository,
          );

          final response = await onRequest(context);
          expect(response.statusCode, HttpStatus.noContent);

          // Verify user update
          final capturedUser =
              verify(
                    () => mockUserRepository.update(
                      id: user.id,
                      item: captureAny(named: 'item'),
                    ),
                  ).captured.single
                  as User;
          expect(capturedUser.photoUrl, isNull);

          // Verify asset deletion
          verify(() => mockMediaAssetRepository.delete(id: asset.id)).called(1);

          // Verify idempotency
          verify(() => mockIdempotencyService.recordEvent('msg-123')).called(1);
        },
      );

      test('does not update user if photoUrl does not match', () async {
        final asset = createTestMediaAsset(
          purpose: MediaAssetPurpose.userProfilePhoto,
          publicUrl: 'http://public/url',
          associatedEntityId: 'user-id',
          associatedEntityType: MediaAssetEntityType.user,
        );
        // User has a *different* photo URL
        final user = createTestUser(
          id: asset.userId,
          photoUrl: 'http://some.other/url',
        );

        when(
          () => mockMediaAssetRepository.readAll(
            filter: {'storagePath': asset.storagePath},
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [asset],
            cursor: null,
            hasMore: false,
          ),
        );
        when(
          () => mockUserRepository.read(id: user.id),
        ).thenAnswer((_) async => user);

        final context = createMockRequestContext(
          method: HttpMethod.post,
          body: createGcsNotificationPayload(
            'msg-123',
            'OBJECT_DELETE',
            asset.storagePath,
          ),
          idempotencyService: mockIdempotencyService,
          mediaAssetRepository: mockMediaAssetRepository,
          userRepository: mockUserRepository,
          headlineRepository: mockHeadlineRepository,
          storageService: mockStorageService,
          topicRepository: mockTopicRepository,
          sourceRepository: mockSourceRepository,
        );

        await onRequest(context);

        verifyNever(
          () => mockUserRepository.update(
            id: any(named: 'id'),
            item: any(named: 'item'),
          ),
        );
        verify(() => mockMediaAssetRepository.delete(id: asset.id)).called(1);
      });

      test(
        'only deletes asset record for non-userProfilePhoto delete',
        () async {
          final asset = createTestMediaAsset(
            purpose: MediaAssetPurpose.headlineImage,
            associatedEntityId: null,
          );

          when(
            () => mockMediaAssetRepository.readAll(
              filter: {'storagePath': asset.storagePath},
              pagination: any(named: 'pagination'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [asset],
              cursor: null,
              hasMore: false,
            ),
          );

          final context = createMockRequestContext(
            method: HttpMethod.post,
            body: createGcsNotificationPayload(
              'msg-123',
              'OBJECT_DELETE',
              asset.storagePath,
            ),
            idempotencyService: mockIdempotencyService,
            mediaAssetRepository: mockMediaAssetRepository,
            headlineRepository: mockHeadlineRepository,
            userRepository: mockUserRepository,
            storageService: mockStorageService,
            topicRepository: mockTopicRepository,
            sourceRepository: mockSourceRepository,
          );

          final response = await onRequest(context);
          expect(response.statusCode, HttpStatus.noContent);

          verifyNever(() => mockHeadlineRepository.read(id: any(named: 'id')));
          verify(() => mockMediaAssetRepository.delete(id: asset.id)).called(1);
          verify(() => mockIdempotencyService.recordEvent('msg-123')).called(1);
        },
      );
    });
  });
}
