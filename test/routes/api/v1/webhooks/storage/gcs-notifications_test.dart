import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
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

    setUpAll(() {
      registerSharedFallbackValues();
      mockGcsJwtVerification();
      mockEnvironmentConfig();
    });

    setUp(() {
      mockIdempotencyService = MockIdempotencyService();
      mockMediaAssetRepository = MockMediaAssetRepository();
      mockUserRepository = MockUserRepository();
      mockStorageService = MockStorageService();

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
        () => mockMediaAssetRepository.readAll(filter: any(named: 'filter')),
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
      );

      final response = await onRequest(context);
      expect(response.statusCode, HttpStatus.ok);
    });

    group('OBJECT_FINALIZE', () {
      test(
        'updates asset status and user photoUrl on userProfilePhoto finalize',
        () async {
          final user = createTestUser(photoUrl: 'old-url');
          final newAsset = createTestMediaAsset(
            purpose: MediaAssetPurpose.userProfilePhoto,
            userId: user.id,
          );
          final oldAsset = createTestMediaAsset(
            id: 'old-asset-id',
            purpose: MediaAssetPurpose.userProfilePhoto,
            userId: user.id,
            storagePath: 'old/path.jpg',
          );

          when(
            () => mockMediaAssetRepository.readAll(
              filter: {'storagePath': newAsset.storagePath},
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [newAsset],
              cursor: null,
              hasMore: false,
            ),
          );
          when(
            () => mockUserRepository.read(id: user.id),
          ).thenAnswer((_) async => user);
          when(
            () => mockMediaAssetRepository.readAll(
              filter: {
                'userId': user.id,
                'purpose': MediaAssetPurpose.userProfilePhoto.name,
                '_id': {r'$ne': newAsset.id},
              },
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
            storageService: mockStorageService,
          );

          final response = await onRequest(context);
          expect(response.statusCode, HttpStatus.noContent);

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
          expect(capturedUser.photoUrl, contains(newAsset.storagePath));

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
          expect(capturedAsset.publicUrl, isNotNull);

          // Verify idempotency
          verify(() => mockIdempotencyService.recordEvent('msg-123')).called(1);
        },
      );

      test(
        'only updates asset status for non-userProfilePhoto finalize',
        () async {
          final asset = createTestMediaAsset(
            purpose: MediaAssetPurpose.headlineImage,
          );

          when(
            () => mockMediaAssetRepository.readAll(
              filter: {'storagePath': asset.storagePath},
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
              'OBJECT_FINALIZE',
              asset.storagePath,
            ),
            idempotencyService: mockIdempotencyService,
            mediaAssetRepository: mockMediaAssetRepository,
            userRepository: mockUserRepository,
            storageService: mockStorageService,
          );

          final response = await onRequest(context);
          expect(response.statusCode, HttpStatus.noContent);

          verifyNever(
            () => mockUserRepository.update(
              id: any(named: 'id'),
              item: any(named: 'item'),
            ),
          );

          final capturedAsset =
              verify(
                    () => mockMediaAssetRepository.update(
                      id: asset.id,
                      item: captureAny(named: 'item'),
                    ),
                  ).captured.single
                  as MediaAsset;
          expect(capturedAsset.status, MediaAssetStatus.completed);
          expect(capturedAsset.publicUrl, isNotNull);

          verify(() => mockIdempotencyService.recordEvent('msg-123')).called(1);
        },
      );
    });

    group('OBJECT_DELETE', () {
      test(
        'deletes asset record and nullifies user photoUrl on userProfilePhoto delete',
        () async {
          final asset = createTestMediaAsset(
            purpose: MediaAssetPurpose.userProfilePhoto,
            publicUrl: 'http://public/url',
          );
          final user = createTestUser(
            id: asset.userId,
            photoUrl: asset.publicUrl,
          );

          when(
            () => mockMediaAssetRepository.readAll(
              filter: {'storagePath': asset.storagePath},
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
        );
        // User has a *different* photo URL
        final user = createTestUser(
          id: asset.userId,
          photoUrl: 'http://some.other/url',
        );

        when(
          () => mockMediaAssetRepository.readAll(
            filter: {'storagePath': asset.storagePath},
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
          );

          when(
            () => mockMediaAssetRepository.readAll(
              filter: {'storagePath': asset.storagePath},
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
            userRepository: mockUserRepository,
          );

          final response = await onRequest(context);
          expect(response.statusCode, HttpStatus.noContent);

          verifyNever(() => mockUserRepository.read(id: any(named: 'id')));
          verify(() => mockMediaAssetRepository.delete(id: asset.id)).called(1);
          verify(() => mockIdempotencyService.recordEvent('msg-123')).called(1);
        },
      );
    });
  });
}
