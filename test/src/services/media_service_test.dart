import 'package:core/core.dart';

import 'package:flutter_news_app_api_server_full_source_code/src/services/media_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/storage/i_storage_service.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockDataRepository<T> extends Mock implements DataRepository<T> {}

class MockStorageService extends Mock implements IStorageService {}

class MockLogger extends Mock implements Logger {}

void main() {
  late MediaService mediaService;
  late MockDataRepository<MediaAsset> mockMediaAssetRepo;
  late MockDataRepository<User> mockUserRepo;
  late MockDataRepository<Headline> mockHeadlineRepo;
  late MockDataRepository<Topic> mockTopicRepo;
  late MockDataRepository<Source> mockSourceRepo;
  late MockStorageService mockStorageService;
  late MockLogger mockLogger;

  setUp(() {
    mockMediaAssetRepo = MockDataRepository<MediaAsset>();
    mockUserRepo = MockDataRepository<User>();
    mockHeadlineRepo = MockDataRepository<Headline>();
    mockTopicRepo = MockDataRepository<Topic>();
    mockSourceRepo = MockDataRepository<Source>();
    mockStorageService = MockStorageService();
    mockLogger = MockLogger();

    mediaService = MediaService(
      mediaAssetRepository: mockMediaAssetRepo,
      userRepository: mockUserRepo,
      headlineRepository: mockHeadlineRepo,
      topicRepository: mockTopicRepo,
      sourceRepository: mockSourceRepo,
      storageService: mockStorageService,
      log: mockLogger,
    );

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
    registerFallbackValue(
      User(
        id: 'fallback',
        email: 'fallback',
        role: UserRole.user,
        tier: AccessTier.standard,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );

    const fallbackCountry = Country(
      id: 'fallback',
      isoCode: 'US',
      name: {SupportedLanguage.en: 'fallback'},
      flagUrl: 'fallback',
    );
    final fallbackSource = Source(
      id: 'fallback',
      name: const {SupportedLanguage.en: 'fallback'},
      description: const {SupportedLanguage.en: 'fallback'},
      url: 'fallback',
      sourceType: SourceType.blog,
      language: SupportedLanguage.en,
      headquarters: fallbackCountry,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      status: ContentStatus.active,
    );
    final fallbackTopic = Topic(
      id: 'fallback',
      name: const {SupportedLanguage.en: 'fallback'},
      description: const {SupportedLanguage.en: 'fallback'},
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      status: ContentStatus.active,
    );

    registerFallbackValue(
      Headline(
        id: 'fallback',
        title: const {SupportedLanguage.en: 'fallback'},
        url: 'fallback',
        imageUrl: 'fallback',
        source: fallbackSource,
        eventCountry: fallbackCountry,
        topic: fallbackTopic,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        status: ContentStatus.active,
        isBreaking: false,
      ),
    );

    registerFallbackValue(const PaginationOptions());

    // Mock generic update responses
    when(
      () => mockMediaAssetRepo.update(
        id: any(named: 'id'),
        item: any(named: 'item'),
      ),
    ).thenAnswer(
      (invocation) async => invocation.namedArguments[#item] as MediaAsset,
    );
  });

  group('MediaService', () {
    group('finalizeUpload', () {
      test('finalizes user profile photo and updates user', () async {
        final mediaAsset = MediaAsset(
          id: 'asset1',
          userId: 'user1',
          purpose: MediaAssetPurpose.userProfilePhoto,
          status: MediaAssetStatus.pendingUpload,
          storagePath: 'path/to/new.jpg',
          contentType: 'image/jpeg',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        );

        final user = User(
          id: 'user1',
          email: 'test@example.com',
          role: UserRole.user,
          tier: AccessTier.standard,
          createdAt: DateTime.now(),
          mediaAssetId: 'asset1', // User is waiting for this asset
          photoUrl: 'https://old-url.com/old.jpg', // Has an old photo
        );

        // 1. Mock finding the user waiting for this asset
        when(
          () => mockUserRepo.readAll(filter: {'mediaAssetId': 'asset1'}),
        ).thenAnswer(
          (_) async =>
              PaginatedResponse(items: [user], cursor: null, hasMore: false),
        );

        // 2. Mock finding the old asset to clean it up
        when(
          () => mockMediaAssetRepo.readAll(
            filter: {'publicUrl': 'https://old-url.com/old.jpg'},
            pagination: any(named: 'pagination'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [
              mediaAsset.copyWith(
                id: 'old_asset',
                storagePath: 'path/to/old.jpg',
                status: MediaAssetStatus.completed,
              ),
            ],
            cursor: null,
            hasMore: false,
          ),
        );

        // 3. Mock cleanup operations
        when(
          () => mockStorageService.deleteObject(storagePath: 'path/to/old.jpg'),
        ).thenAnswer((_) async {});
        when(
          () => mockMediaAssetRepo.delete(id: 'old_asset'),
        ).thenAnswer((_) async {});

        // 4. Mock user update
        when(
          () => mockUserRepo.update(
            id: 'user1',
            item: any(named: 'item'),
          ),
        ).thenAnswer(
          (invocation) async => invocation.namedArguments[#item] as User,
        );

        await mediaService.finalizeUpload(
          mediaAsset: mediaAsset,
          publicUrl: 'https://new-url.com/new.jpg',
        );

        // Yield to the event loop to allow the unawaited cleanup task to execute.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Verify User was updated with new URL and nullified mediaAssetId
        verify(
          () => mockUserRepo.update(
            id: 'user1',
            item: any(
              named: 'item',
              that: isA<User>()
                  .having(
                    (u) => u.photoUrl,
                    'photoUrl',
                    'https://new-url.com/new.jpg',
                  )
                  .having((u) => u.mediaAssetId, 'mediaAssetId', null),
            ),
          ),
        ).called(1);

        // Verify MediaAsset was marked completed
        verify(
          () => mockMediaAssetRepo.update(
            id: 'asset1',
            item: any(
              named: 'item',
              that: isA<MediaAsset>()
                  .having((a) => a.status, 'status', MediaAssetStatus.completed)
                  .having(
                    (a) => a.publicUrl,
                    'publicUrl',
                    'https://new-url.com/new.jpg',
                  )
                  .having(
                    (a) => a.associatedEntityId,
                    'associatedEntityId',
                    'user1',
                  ),
            ),
          ),
        ).called(1);

        // Verify cleanup was attempted.
        verify(
          () => mockStorageService.deleteObject(storagePath: 'path/to/old.jpg'),
        ).called(1);
      });
    });

    group('handleAssetDeletion', () {
      test('nullifies parent entity URL and deletes asset record', () async {
        final mediaAsset = MediaAsset(
          id: 'asset1',
          userId: 'user1',
          purpose: MediaAssetPurpose.headlineImage,
          status: MediaAssetStatus.completed,
          storagePath: 'path/to/img.jpg',
          contentType: 'image/jpeg',
          publicUrl: 'https://bucket/img.jpg',
          associatedEntityId: 'headline1',
          associatedEntityType: MediaAssetEntityType.headline,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        );

        final headline = Headline(
          id: 'headline1',
          title: const {SupportedLanguage.en: 'Test'},
          url: 'https://example.com/article',
          source: Source(
            id: 's1',
            name: const {SupportedLanguage.en: 'S'},
            description: const {SupportedLanguage.en: 'D'},
            url: 'u',
            sourceType: SourceType.blog,
            language: SupportedLanguage.en,
            headquarters: const Country(
              id: 'c',
              isoCode: 'US',
              name: {SupportedLanguage.en: 'US'},
              flagUrl: 'f',
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ContentStatus.active,
          ),
          eventCountry: const Country(
            id: 'c',
            isoCode: 'US',
            name: {SupportedLanguage.en: 'US'},
            flagUrl: 'f',
          ),
          topic: Topic(
            id: 't',
            name: const {SupportedLanguage.en: 'T'},
            description: const {SupportedLanguage.en: 'D'},
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            status: ContentStatus.active,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: ContentStatus.active,
          isBreaking: false,
          imageUrl: 'https://bucket/img.jpg', // Matches asset URL
        );

        when(
          () => mockHeadlineRepo.read(id: 'headline1'),
        ).thenAnswer((_) async => headline);

        when(
          () => mockHeadlineRepo.update(
            id: 'headline1',
            item: any(named: 'item'),
          ),
        ).thenAnswer(
          (invocation) async => invocation.namedArguments[#item] as Headline,
        );

        when(
          () => mockMediaAssetRepo.delete(id: 'asset1'),
        ).thenAnswer((_) async {});

        await mediaService.handleAssetDeletion(mediaAsset);

        // Verify Headline was updated to remove the image URL
        verify(
          () => mockHeadlineRepo.update(
            id: 'headline1',
            item: any(
              named: 'item',
              that: isA<Headline>().having((h) => h.imageUrl, 'imageUrl', null),
            ),
          ),
        ).called(1);

        verify(() => mockMediaAssetRepo.delete(id: 'asset1')).called(1);
      });
    });
  });
}
