import 'dart:io';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permissions.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../routes/api/v1/media/request-upload-url.dart';
import '../../../../src/helpers/test_helpers.dart';

void main() {
  group('POST /api/v1/media/request-upload-url', () {
    late MockStorageService mockStorageService;
    late MockMediaAssetRepository mockMediaAssetRepository;
    late MockPermissionService mockPermissionService;

    const signedUrl = 'https://storage.googleapis.com/signed-url';

    setUpAll(registerSharedFallbackValues);

    setUp(() {
      mockStorageService = MockStorageService();
      mockMediaAssetRepository = MockMediaAssetRepository();
      mockPermissionService = MockPermissionService();

      when(
        () => mockStorageService.generateUploadUrl(
          storagePath: any<String>(named: 'storagePath'),
          contentType: any<String>(named: 'contentType'),
        ),
      ).thenAnswer((_) async => signedUrl);

      when(
        () => mockMediaAssetRepository.create(
          item: any<MediaAsset>(named: 'item'),
        ),
      ).thenAnswer((invocation) async {
        return invocation.namedArguments[#item] as MediaAsset;
      });
    });

    test('returns 400 if required fields are missing', () async {
      final user = createTestUser();
      final context = createMockRequestContext(
        method: HttpMethod.post,
        body: <String, dynamic>{},
        authenticatedUser: user,
      );

      final response = await onRequest(context);

      expect(response.statusCode, HttpStatus.badRequest);
    });

    test('returns 403 when anonymous user requests userProfilePhoto', () async {
      final anonymousUser = createTestUser(isAnonymous: true);
      final context = createMockRequestContext(
        method: HttpMethod.post,
        body: {
          'fileName': 'profile.jpg',
          'contentType': 'image/jpeg',
          'purpose': 'userProfilePhoto',
        },
        authenticatedUser: anonymousUser,
        permissionService: mockPermissionService,
      );

      final response = await onRequest(context);

      expect(response.statusCode, HttpStatus.forbidden);
    });

    test(
      'returns 403 when user without permission requests headlineImage',
      () async {
        final user = createTestUser(role: UserRole.user);
        when(
          () =>
              mockPermissionService.hasAnyPermission(user, any<Set<String>>()),
        ).thenReturn(false);

        final context = createMockRequestContext(
          method: HttpMethod.post,
          body: {
            'fileName': 'headline.jpg',
            'contentType': 'image/jpeg',
            'purpose': 'headlineImage',
          },
          authenticatedUser: user,
          permissionService: mockPermissionService,
        );

        final response = await onRequest(context);

        expect(response.statusCode, HttpStatus.forbidden);
        verify(
          () => mockPermissionService.hasAnyPermission(user, {
            Permissions.headlineCreate,
            Permissions.headlineUpdate,
          }),
        ).called(1);
      },
    );

    test('returns 200 when publisher requests headlineImage', () async {
      final publisher = createTestUser(role: UserRole.publisher);
      when(
        () => mockPermissionService.hasAnyPermission(
          publisher,
          any<Set<String>>(),
        ),
      ).thenReturn(true);

      final context = createMockRequestContext(
        method: HttpMethod.post,
        body: {
          'fileName': 'headline.jpg',
          'contentType': 'image/jpeg',
          'purpose': 'headlineImage',
        },
        authenticatedUser: publisher,
        storageService: mockStorageService,
        mediaAssetRepository: mockMediaAssetRepository,
        permissionService: mockPermissionService,
      );

      final response = await onRequest(context);

      expect(response.statusCode, HttpStatus.ok);
      final json = await response.json() as Map<String, dynamic>;
      expect(json['signedUrl'], signedUrl);
      expect(json['mediaAssetId'], isA<String>());
    });

    test(
      'on success, creates MediaAsset and returns signed URL and asset ID',
      () async {
        final user = createTestUser();
        final context = createMockRequestContext(
          method: HttpMethod.post,
          body: {
            'fileName': 'profile.jpg',
            'contentType': 'image/jpeg',
            'purpose': 'userProfilePhoto',
          },
          authenticatedUser: user,
          storageService: mockStorageService,
          mediaAssetRepository: mockMediaAssetRepository,
          permissionService: mockPermissionService,
        );

        final response = await onRequest(context);

        expect(response.statusCode, HttpStatus.ok);

        final capturedAsset =
            verify(
                  () => mockMediaAssetRepository.create(
                    item: captureAny<MediaAsset>(named: 'item'),
                  ),
                ).captured.single
                as MediaAsset;

        expect(capturedAsset.userId, user.id);
        expect(capturedAsset.purpose, MediaAssetPurpose.userProfilePhoto);
        expect(capturedAsset.status, MediaAssetStatus.pendingUpload);
        expect(capturedAsset.contentType, 'image/jpeg');
        expect(capturedAsset.storagePath, startsWith('user-media/${user.id}/'));
        expect(capturedAsset.storagePath, endsWith('.jpg'));

        verify(
          () => mockStorageService.generateUploadUrl(
            storagePath: capturedAsset.storagePath,
            contentType: 'image/jpeg',
          ),
        ).called(1);

        final json = await response.json() as Map<String, dynamic>;
        expect(json['signedUrl'], signedUrl);
        expect(json['mediaAssetId'], capturedAsset.id);
      },
    );

    test('returns 405 for non-POST methods', () async {
      final context = createMockRequestContext(method: HttpMethod.get);
      final response = await onRequest(context);
      expect(response.statusCode, HttpStatus.methodNotAllowed);
    });
  });
}
