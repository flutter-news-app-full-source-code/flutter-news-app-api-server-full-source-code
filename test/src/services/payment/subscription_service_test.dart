import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/app_store_server_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/google_play_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/payment/payment.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/payment.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/payment/idempotency_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/payment/subscription_service.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockDataRepository<T> extends Mock implements DataRepository<T> {}

class MockAppStoreServerClient extends Mock implements AppStoreServerClient {}

class MockGooglePlayClient extends Mock implements GooglePlayClient {}

class MockIdempotencyService extends Mock implements IdempotencyService {}

class MockLogger extends Mock implements Logger {}

class MockAppleSubscriptionResponse extends Mock
    implements AppleSubscriptionResponse {}

class MockAppleSubscriptionGroupItem extends Mock
    implements AppleSubscriptionGroupItem {}

class MockAppleLastTransactionItem extends Mock
    implements AppleLastTransactionItem {}

class MockGoogleSubscriptionNotification extends Mock
    implements GoogleSubscriptionNotification {}

void main() {
  group('SubscriptionService', () {
    late DataRepository<UserSubscription> mockUserSubscriptionRepository;
    late DataRepository<User> mockUserRepository;
    late AppStoreServerClient mockAppStoreClient;
    late GooglePlayClient mockGooglePlayClient;
    late IdempotencyService mockIdempotencyService;
    late Logger mockLogger;
    late SubscriptionService service;

    final testUser = User(
      id: 'user-1',
      email: 'test@example.com',
      role: UserRole.user,
      tier: AccessTier.standard,
      createdAt: DateTime.now(),
    );

    setUpAll(() {
      registerFallbackValue(
        User(
          id: 'user-1',
          email: 'test@example.com',
          role: UserRole.user,
          tier: AccessTier.standard,
          createdAt: DateTime.now(),
        ),
      );
      registerFallbackValue(
        UserSubscription(
          id: 'sub-1',
          userId: 'user-1',
          tier: AccessTier.premium,
          status: SubscriptionStatus.active,
          provider: StoreProvider.apple,
          validUntil: DateTime.now().add(const Duration(days: 30)),
          willAutoRenew: true,
          originalTransactionId: 'orig-trans-id',
        ),
      );
    });

    setUp(() {
      mockUserSubscriptionRepository = MockDataRepository<UserSubscription>();
      mockUserRepository = MockDataRepository<User>();
      mockAppStoreClient = MockAppStoreServerClient();
      mockGooglePlayClient = MockGooglePlayClient();
      mockIdempotencyService = MockIdempotencyService();
      mockLogger = MockLogger();

      service = SubscriptionService(
        userSubscriptionRepository: mockUserSubscriptionRepository,
        userRepository: mockUserRepository,
        appStoreClient: mockAppStoreClient,
        googlePlayClient: mockGooglePlayClient,
        idempotencyService: mockIdempotencyService,
        log: mockLogger,
      );

      // Default stubs for successful repository calls
      when(
        () => mockUserRepository.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      ).thenAnswer((_) async => testUser);
      when(
        () => mockUserSubscriptionRepository.create(item: any(named: 'item')),
      ).thenAnswer(
        (_) async => UserSubscription(
          id: 'sub-1',
          userId: 'user-1',
          tier: AccessTier.premium,
          status: SubscriptionStatus.active,
          provider: StoreProvider.apple,
          validUntil: DateTime.now().add(const Duration(days: 30)),
          willAutoRenew: true,
          originalTransactionId: 'orig-trans-id',
        ),
      );
      when(
        () => mockUserSubscriptionRepository.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      ).thenAnswer(
        (_) async => UserSubscription(
          id: 'sub-1',
          userId: 'user-1',
          tier: AccessTier.premium,
          status: SubscriptionStatus.active,
          provider: StoreProvider.apple,
          validUntil: DateTime.now().add(const Duration(days: 30)),
          willAutoRenew: true,
          originalTransactionId: 'orig-trans-id',
        ),
      );
      when(
        () => mockIdempotencyService.recordEvent(any()),
      ).thenAnswer((_) async {});
    });

    group('verifyAndProcessPurchase', () {
      const transaction = PurchaseTransaction(
        provider: StoreProvider.google,
        providerReceipt: 'google-receipt',
        planId: 'monthly.premium',
      );

      setUp(() {
        // Default idempotency check to false (not processed)
        when(
          () => mockIdempotencyService.isEventProcessed(any()),
        ).thenAnswer((_) async => false);
      });

      test(
        'returns existing subscription if event is already processed',
        () async {
          when(
            () => mockIdempotencyService.isEventProcessed(any()),
          ).thenAnswer((_) async => true);
          final existingSub = UserSubscription(
            id: 'sub-1',
            userId: testUser.id,
            tier: AccessTier.premium,
            status: SubscriptionStatus.active,
            provider: StoreProvider.google,
            validUntil: DateTime.now().add(const Duration(days: 30)),
            willAutoRenew: true,
            originalTransactionId: 'google-receipt',
          );
          when(
            () => mockUserSubscriptionRepository.readAll(
              filter: any(named: 'filter'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [existingSub],
              cursor: null,
              hasMore: false,
            ),
          );

          final result = await service.verifyAndProcessPurchase(
            user: testUser,
            transaction: transaction,
          );

          expect(result, equals(existingSub));
          verifyNever(
            () => mockGooglePlayClient.getSubscription(
              subscriptionId: any(named: 'subscriptionId'),
              purchaseToken: any(named: 'purchaseToken'),
            ),
          );
        },
      );

      test('processes new Google purchase successfully', () async {
        when(
          () => mockUserSubscriptionRepository.readAll(
            filter: any(named: 'filter'),
          ),
        ).thenAnswer(
          (_) async =>
              const PaginatedResponse(items: [], cursor: null, hasMore: false),
        );
        when(
          () => mockGooglePlayClient.getSubscription(
            subscriptionId: any(named: 'subscriptionId'),
            purchaseToken: any(named: 'purchaseToken'),
          ),
        ).thenAnswer(
          (_) async => GoogleSubscriptionPurchase(
            expiryTimeMillis: DateTime.now()
                .add(const Duration(days: 30))
                .millisecondsSinceEpoch
                .toString(),
            autoRenewing: true,
          ),
        );

        await service.verifyAndProcessPurchase(
          user: testUser,
          transaction: transaction,
        );

        verify(
          () => mockUserSubscriptionRepository.create(item: any(named: 'item')),
        ).called(1);
        final capturedUser =
            verify(
                  () => mockUserRepository.update(
                    id: testUser.id,
                    item: captureAny(named: 'item'),
                  ),
                ).captured.first
                as User;
        expect(capturedUser.tier, AccessTier.premium);
        verify(
          () => mockIdempotencyService.recordEvent(transaction.providerReceipt),
        ).called(1);
      });

      test('processes new Apple purchase successfully', () async {
        final appleTransaction = transaction.copyWith(
          provider: StoreProvider.apple,
          providerReceipt: 'apple-receipt',
        );

        // Mock Apple Client responses
        final mockResponse = MockAppleSubscriptionResponse();
        final mockGroup = MockAppleSubscriptionGroupItem();
        final mockAppleTransInfo = MockAppleLastTransactionItem();

        when(
          () => mockAppleTransInfo.originalTransactionId,
        ).thenReturn('apple-receipt');
        when(
          () => mockAppleTransInfo.signedTransactionInfo,
        ).thenReturn('signed-info');

        when(() => mockGroup.lastTransactions).thenReturn([mockAppleTransInfo]);
        when(() => mockResponse.data).thenReturn([mockGroup]);

        when(
          () => mockAppStoreClient.getAllSubscriptionStatuses(any()),
        ).thenAnswer((_) async => mockResponse);

        when(
          () => mockAppStoreClient.decodeTransaction(any()),
        ).thenReturn(
          AppleTransactionDecodedPayload(
            originalTransactionId: 'apple-receipt',
            transactionId: 'trans-id',
            productId: 'prod-id',
            purchaseDate: DateTime.now(),
            originalPurchaseDate: DateTime.now(),
            expiresDate: DateTime.now().add(const Duration(days: 30)),
            type: 'Auto-Renewable Subscription',
            inAppOwnershipType: 'PURCHASED',
          ),
        );

        when(
          () => mockUserSubscriptionRepository.readAll(
            filter: any(named: 'filter'),
          ),
        ).thenAnswer(
          (_) async =>
              const PaginatedResponse(items: [], cursor: null, hasMore: false),
        );

        await service.verifyAndProcessPurchase(
          user: testUser,
          transaction: appleTransaction,
        );

        verify(
          () => mockUserSubscriptionRepository.create(item: any(named: 'item')),
        ).called(1);
        verify(
          () => mockUserRepository.update(
            id: testUser.id,
            item: any(named: 'item'),
          ),
        ).called(1);
      });

      test(
        're-processes purchase if idempotency record exists but subscription does not',
        () async {
          // Simulate event processed
          when(
            () => mockIdempotencyService.isEventProcessed(any()),
          ).thenAnswer((_) async => true);

          // Simulate NO existing subscription found
          when(
            () => mockUserSubscriptionRepository.readAll(
              filter: any(named: 'filter'),
            ),
          ).thenAnswer(
            (_) async => const PaginatedResponse(
              items: [],
              cursor: null,
              hasMore: false,
            ),
          );

          // Should proceed to call Google Client
          when(
            () => mockGooglePlayClient.getSubscription(
              subscriptionId: any(named: 'subscriptionId'),
              purchaseToken: any(named: 'purchaseToken'),
            ),
          ).thenAnswer(
            (_) async => GoogleSubscriptionPurchase(
              expiryTimeMillis: DateTime.now()
                  .add(const Duration(days: 30))
                  .millisecondsSinceEpoch
                  .toString(),
              autoRenewing: true,
            ),
          );

          await service.verifyAndProcessPurchase(
            user: testUser,
            transaction: transaction,
          );

          verify(() => mockLogger.warning(any())).called(1);
        },
      );

      test(
        'does not perform redundant user update if user is already premium',
        () async {
          // Setup: User is ALREADY premium
          final premiumUser = testUser.copyWith(tier: AccessTier.premium);

          // Setup: Valid Google Purchase
          when(
            () => mockUserSubscriptionRepository.readAll(
              filter: any(named: 'filter'),
            ),
          ).thenAnswer(
            (_) async => const PaginatedResponse(
              items: [],
              cursor: null,
              hasMore: false,
            ),
          );
          when(
            () => mockGooglePlayClient.getSubscription(
              subscriptionId: any(named: 'subscriptionId'),
              purchaseToken: any(named: 'purchaseToken'),
            ),
          ).thenAnswer(
            (_) async => GoogleSubscriptionPurchase(
              expiryTimeMillis: DateTime.now()
                  .add(const Duration(days: 30))
                  .millisecondsSinceEpoch
                  .toString(),
              autoRenewing: true,
            ),
          );

          await service.verifyAndProcessPurchase(
            user: premiumUser,
            transaction: transaction,
          );

          // Verify User Update NEVER called (because they are already premium)
          verifyNever(
            () => mockUserRepository.update(
              id: any(named: 'id'),
              item: any(named: 'item'),
            ),
          );
        },
      );

      test(
        'transfers entitlement (Restore Purchase) when subscription belongs to a different user',
        () async {
          // 1. Setup: Transaction that resolves to an ID owned by 'old-user'
          when(
            () => mockUserSubscriptionRepository.readAll(
              filter: any(named: 'filter'),
            ),
          ).thenAnswer((invocation) async {
            final filter =
                invocation.namedArguments[#filter] as Map<String, dynamic>;
            // If looking up by originalTransactionId, return the OLD user's sub
            if (filter.containsKey('originalTransactionId')) {
              return PaginatedResponse(
                items: [
                  UserSubscription(
                    id: 'sub-old',
                    userId: 'user-old', // Different user
                    tier: AccessTier.premium,
                    status: SubscriptionStatus.active,
                    provider: StoreProvider.google,
                    validUntil: DateTime.now().add(const Duration(days: 30)),
                    willAutoRenew: true,
                    originalTransactionId: transaction.providerReceipt,
                  ),
                ],
                cursor: null,
                hasMore: false,
              );
            }
            // If looking up by userId (for the current user), return empty (new install)
            if (filter['userId'] == testUser.id) {
              return const PaginatedResponse(
                items: [],
                cursor: null,
                hasMore: false,
              );
            }
            return const PaginatedResponse(
              items: [],
              cursor: null,
              hasMore: false,
            );
          });

          // 2. Mock Google Client to return valid purchase
          when(
            () => mockGooglePlayClient.getSubscription(
              subscriptionId: any(named: 'subscriptionId'),
              purchaseToken: any(named: 'purchaseToken'),
            ),
          ).thenAnswer(
            (_) async => GoogleSubscriptionPurchase(
              expiryTimeMillis: DateTime.now()
                  .add(const Duration(days: 30))
                  .millisecondsSinceEpoch
                  .toString(),
              autoRenewing: true,
            ),
          );

          // 3. Mock Old User Retrieval & Downgrade
          final oldUser = User(
            id: 'user-old',
            email: 'old@example.com',
            role: UserRole.user,
            tier: AccessTier.premium,
            createdAt: DateTime.now(),
          );
          when(
            () => mockUserRepository.read(id: 'user-old'),
          ).thenAnswer((_) async => oldUser);

          // 4. Execute
          await service.verifyAndProcessPurchase(
            user: testUser,
            transaction: transaction,
          );

          // 5. Verify Transfer Logic
          // A. Old user should be downgraded
          verify(
            () => mockUserRepository.update(
              id: 'user-old',
              item: any(
                named: 'item',
                that: isA<User>().having(
                  (u) => u.tier,
                  'tier',
                  AccessTier.standard,
                ),
              ),
            ),
          ).called(1);

          // B. Subscription ownership should be transferred to current user
          verify(
            () => mockUserSubscriptionRepository.update(
              id: 'sub-old',
              item: any(
                named: 'item',
                that: isA<UserSubscription>().having(
                  (s) => s.userId,
                  'userId',
                  testUser.id,
                ),
              ),
            ),
          ).called(1);

          // C. Current user should be upgraded (happens in main flow)
          verify(
            () => mockUserRepository.update(
              id: testUser.id,
              item: any(
                named: 'item',
                that: isA<User>().having(
                  (u) => u.tier,
                  'tier',
                  AccessTier.premium,
                ),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'handles expired purchase correctly (does not upgrade user)',
        () async {
          // Setup: Google purchase that is expired
          when(
            () => mockUserSubscriptionRepository.readAll(
              filter: any(named: 'filter'),
            ),
          ).thenAnswer(
            (_) async => const PaginatedResponse(
              items: [],
              cursor: null,
              hasMore: false,
            ),
          );
          when(
            () => mockGooglePlayClient.getSubscription(
              subscriptionId: any(named: 'subscriptionId'),
              purchaseToken: any(named: 'purchaseToken'),
            ),
          ).thenAnswer(
            (_) async => GoogleSubscriptionPurchase(
              expiryTimeMillis: DateTime.now()
                  .subtract(const Duration(days: 30)) // Expired
                  .millisecondsSinceEpoch
                  .toString(),
              autoRenewing: false,
            ),
          );

          final result = await service.verifyAndProcessPurchase(
            user: testUser, // Standard user
            transaction: transaction,
          );

          // Verify subscription created as expired
          expect(result.status, SubscriptionStatus.expired);
          verify(
            () => mockUserSubscriptionRepository.create(
              item: any(
                named: 'item',
                that: isA<UserSubscription>().having(
                  (s) => s.status,
                  'status',
                  SubscriptionStatus.expired,
                ),
              ),
            ),
          ).called(1);

          // Verify user was NOT updated (remains standard)
          verifyNever(
            () => mockUserRepository.update(
              id: any(named: 'id'),
              item: any(named: 'item'),
            ),
          );
        },
      );

      test(
        'transfers entitlement gracefully when old user is not found (deleted)',
        () async {
          // 1. Setup: Transaction resolves to sub owned by 'user-old'
          when(
            () => mockUserSubscriptionRepository.readAll(
              filter: any(named: 'filter'),
            ),
          ).thenAnswer((invocation) async {
            final filter =
                invocation.namedArguments[#filter] as Map<String, dynamic>;
            if (filter.containsKey('originalTransactionId')) {
              return PaginatedResponse(
                items: [
                  UserSubscription(
                    id: 'sub-old',
                    userId: 'user-old',
                    tier: AccessTier.premium,
                    status: SubscriptionStatus.active,
                    provider: StoreProvider.google,
                    validUntil: DateTime.now().add(const Duration(days: 30)),
                    willAutoRenew: true,
                    originalTransactionId: transaction.providerReceipt,
                  ),
                ],
                cursor: null,
                hasMore: false,
              );
            }
            return const PaginatedResponse(
              items: [],
              cursor: null,
              hasMore: false,
            );
          });

          // 2. Mock Google Client valid purchase
          when(
            () => mockGooglePlayClient.getSubscription(
              subscriptionId: any(named: 'subscriptionId'),
              purchaseToken: any(named: 'purchaseToken'),
            ),
          ).thenAnswer(
            (_) async => GoogleSubscriptionPurchase(
              expiryTimeMillis: DateTime.now()
                  .add(const Duration(days: 30))
                  .millisecondsSinceEpoch
                  .toString(),
              autoRenewing: true,
            ),
          );

          // 3. Mock Old User Lookup -> THROWS NotFoundException
          when(
            () => mockUserRepository.read(id: 'user-old'),
          ).thenThrow(const NotFoundException('User not found'));

          // 4. Execute
          await service.verifyAndProcessPurchase(
            user: testUser,
            transaction: transaction,
          );

          // 5. Verify Resilience
          // Old user update should NOT be called (since read failed)
          verifyNever(
            () => mockUserRepository.update(
              id: 'user-old',
              item: any(named: 'item'),
            ),
          );

          // Subscription SHOULD be transferred to new user
          verify(
            () => mockUserSubscriptionRepository.update(
              id: 'sub-old',
              item: any(
                named: 'item',
                that: isA<UserSubscription>().having(
                  (s) => s.userId,
                  'userId',
                  testUser.id,
                ),
              ),
            ),
          ).called(1);

          // New user SHOULD be upgraded
          verify(
            () => mockUserRepository.update(
              id: testUser.id,
              item: any(named: 'item'),
            ),
          ).called(1);
        },
      );
    });

    group('handleAppleNotification', () {
      final transactionInfo = AppleTransactionDecodedPayload(
        originalTransactionId: 'orig-trans-id',
        transactionId: 'trans-id',
        productId: 'prod-id',
        purchaseDate: DateTime.now(),
        originalPurchaseDate: DateTime.now(),
        expiresDate: DateTime.now().add(const Duration(days: 30)),
        type: 'Auto-Renewable Subscription',
        inAppOwnershipType: 'PURCHASED',
      );

      final notificationPayload = AppleNotificationPayload(
        notificationType: AppleNotificationType.didRenew,
        notificationUUID: 'notif-uuid',
        version: '2.0',
        signedDate: DateTime.now(),
        data: const AppleNotificationData(
          signedTransactionInfo: 'signed-info',
          signedRenewalInfo: 'signed-renewal',
          bundleId: 'com.example',
          environment: AppleEnvironment.sandbox,
        ),
      );

      setUp(() {
        when(
          () => mockIdempotencyService.isEventProcessed(any()),
        ).thenAnswer((_) async => false);
      });

      test('returns early if notification is already processed', () async {
        when(
          () => mockIdempotencyService.isEventProcessed(any()),
        ).thenAnswer((_) async => true);

        await service.handleAppleNotification(notificationPayload);

        verifyNever(() => mockAppStoreClient.decodeTransaction(any()));
      });

      test('logs warning and returns if subscription not found', () async {
        when(
          () => mockAppStoreClient.decodeTransaction(any()),
        ).thenReturn(transactionInfo);
        when(
          () => mockUserSubscriptionRepository.readAll(
            filter: any(named: 'filter'),
          ),
        ).thenAnswer(
          (_) async =>
              const PaginatedResponse(items: [], cursor: null, hasMore: false),
        );

        await service.handleAppleNotification(notificationPayload);

        verify(() => mockLogger.warning(any())).called(1);
        verifyNever(
          () => mockUserSubscriptionRepository.update(
            id: any(named: 'id'),
            item: any(named: 'item'),
          ),
        );
      });

      test('updates subscription and user on DID_RENEW notification', () async {
        when(
          () => mockAppStoreClient.decodeTransaction(any()),
        ).thenReturn(transactionInfo);
        final existingSub = UserSubscription(
          id: 'sub-1',
          userId: testUser.id,
          tier: AccessTier.standard,
          status: SubscriptionStatus.expired,
          provider: StoreProvider.apple,
          validUntil: DateTime.now().subtract(const Duration(days: 1)),
          originalTransactionId: transactionInfo.originalTransactionId,
          willAutoRenew: false,
        );
        when(
          () => mockUserSubscriptionRepository.readAll(
            filter: any(named: 'filter'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [existingSub],
            cursor: null,
            hasMore: false,
          ),
        );
        when(
          () => mockUserRepository.read(id: testUser.id),
        ).thenAnswer((_) async => testUser);

        await service.handleAppleNotification(notificationPayload);

        final capturedSub =
            verify(
                  () => mockUserSubscriptionRepository.update(
                    id: existingSub.id,
                    item: captureAny(named: 'item'),
                  ),
                ).captured.first
                as UserSubscription;
        expect(capturedSub.status, SubscriptionStatus.active);

        final capturedUser =
            verify(
                  () => mockUserRepository.update(
                    id: testUser.id,
                    item: captureAny(named: 'item'),
                  ),
                ).captured.first
                as User;
        expect(capturedUser.tier, AccessTier.premium);

        verify(
          () => mockIdempotencyService.recordEvent(
            notificationPayload.notificationUUID,
          ),
        ).called(1);
      });

      test('downgrades user on EXPIRED notification', () async {
        final expiredPayload = AppleNotificationPayload(
          notificationType: AppleNotificationType.expired,
          notificationUUID: notificationPayload.notificationUUID,
          version: notificationPayload.version,
          signedDate: notificationPayload.signedDate,
          data: notificationPayload.data,
        );

        when(
          () => mockAppStoreClient.decodeTransaction(any()),
        ).thenReturn(transactionInfo);

        // Current state is active
        final activeSub = UserSubscription(
          id: 'sub-1',
          userId: testUser.id,
          tier: AccessTier.premium,
          status: SubscriptionStatus.active,
          provider: StoreProvider.apple,
          validUntil: DateTime.now().add(const Duration(days: 30)),
          originalTransactionId: transactionInfo.originalTransactionId,
          willAutoRenew: true,
        );

        when(
          () => mockUserSubscriptionRepository.readAll(
            filter: any(named: 'filter'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [activeSub],
            cursor: null,
            hasMore: false,
          ),
        );
        when(
          () => mockUserRepository.read(id: testUser.id),
        ).thenAnswer((_) async => testUser.copyWith(tier: AccessTier.premium));

        await service.handleAppleNotification(expiredPayload);

        final capturedSub =
            verify(
                  () => mockUserSubscriptionRepository.update(
                    id: activeSub.id,
                    item: captureAny(named: 'item'),
                  ),
                ).captured.first
                as UserSubscription;
        expect(capturedSub.status, SubscriptionStatus.expired);
        expect(capturedSub.willAutoRenew, false);

        final capturedUser =
            verify(
                  () => mockUserRepository.update(
                    id: testUser.id,
                    item: captureAny(named: 'item'),
                  ),
                ).captured.first
                as User;
        expect(capturedUser.tier, AccessTier.standard);
      });

      test(
        'updates auto-renew status on DID_CHANGE_RENEWAL_STATUS (disabled)',
        () async {
          final payload = AppleNotificationPayload(
            notificationType: AppleNotificationType.didChangeRenewalStatus,
            subtype: AppleNotificationSubtype.autoRenewDisabled,
            notificationUUID: 'uuid-renew',
            version: '2.0',
            signedDate: DateTime.now(),
            data: notificationPayload.data,
          );

          when(
            () => mockAppStoreClient.decodeTransaction(any()),
          ).thenReturn(transactionInfo);

          final activeSub = UserSubscription(
            id: 'sub-1',
            userId: testUser.id,
            tier: AccessTier.premium,
            status: SubscriptionStatus.active,
            provider: StoreProvider.apple,
            validUntil: DateTime.now().add(const Duration(days: 30)),
            originalTransactionId: transactionInfo.originalTransactionId,
            willAutoRenew: true,
          );

          when(
            () => mockUserSubscriptionRepository.readAll(
              filter: any(named: 'filter'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [activeSub],
              cursor: null,
              hasMore: false,
            ),
          );
          when(
            () => mockUserRepository.read(id: testUser.id),
          ).thenAnswer((_) async => testUser);

          await service.handleAppleNotification(payload);

          final capturedSub =
              verify(
                    () => mockUserSubscriptionRepository.update(
                      id: activeSub.id,
                      item: captureAny(named: 'item'),
                    ),
                  ).captured.first
                  as UserSubscription;

          expect(capturedSub.willAutoRenew, false);
        },
      );

      test('downgrades user on REVOKE notification', () async {
        final revokePayload = AppleNotificationPayload(
          notificationType: AppleNotificationType.revoke,
          notificationUUID: 'uuid-revoke',
          version: '2.0',
          signedDate: DateTime.now(),
          data: notificationPayload.data,
        );

        when(
          () => mockAppStoreClient.decodeTransaction(any()),
        ).thenReturn(transactionInfo);

        final activeSub = UserSubscription(
          id: 'sub-1',
          userId: testUser.id,
          tier: AccessTier.premium,
          status: SubscriptionStatus.active,
          provider: StoreProvider.apple,
          validUntil: DateTime.now().add(const Duration(days: 30)),
          originalTransactionId: transactionInfo.originalTransactionId,
          willAutoRenew: true,
        );

        when(
          () => mockUserSubscriptionRepository.readAll(
            filter: any(named: 'filter'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [activeSub],
            cursor: null,
            hasMore: false,
          ),
        );
        when(
          () => mockUserRepository.read(id: testUser.id),
        ).thenAnswer((_) async => testUser.copyWith(tier: AccessTier.premium));

        await service.handleAppleNotification(revokePayload);

        // Verification is identical to EXPIRED test, as logic is shared
        verify(
          () => mockUserSubscriptionRepository.update(
            id: activeSub.id,
            item: any(
              named: 'item',
              that: isA<UserSubscription>().having(
                (s) => s.status,
                'status',
                SubscriptionStatus.expired,
              ),
            ),
          ),
        ).called(1);

        verify(
          () => mockUserRepository.update(
            id: testUser.id,
            item: any(
              named: 'item',
              that: isA<User>().having(
                (u) => u.tier,
                'tier',
                AccessTier.standard,
              ),
            ),
          ),
        ).called(1);
      });
    });

    group('handleGoogleNotification', () {
      const notificationDetails = GoogleSubscriptionDetails(
        subscriptionId: 'sub-id',
        purchaseToken: 'token',
        version: '1.0',
        notificationType: GoogleNotificationType.subscriptionPurchased,
      );
      final notification = GoogleSubscriptionNotification(
        version: '1.0',
        packageName: 'com.example',
        eventTimeMillis: DateTime.now().millisecondsSinceEpoch.toString(),
        subscriptionNotification: notificationDetails,
      );

      setUp(() {
        when(
          () => mockIdempotencyService.isEventProcessed(any()),
        ).thenAnswer((_) async => false);
      });

      test('returns early if notification is already processed', () async {
        when(
          () => mockIdempotencyService.isEventProcessed(any()),
        ).thenAnswer((_) async => true);

        await service.handleGoogleNotification(notification);

        verifyNever(
          () => mockGooglePlayClient.getSubscription(
            subscriptionId: any(named: 'subscriptionId'),
            purchaseToken: any(named: 'purchaseToken'),
          ),
        );
      });

      test(
        'updates subscription and user on active Google notification',
        () async {
          // Mock Google Client to return active subscription
          when(
            () => mockGooglePlayClient.getSubscription(
              subscriptionId: any(named: 'subscriptionId'),
              purchaseToken: any(named: 'purchaseToken'),
            ),
          ).thenAnswer(
            (_) async => GoogleSubscriptionPurchase(
              expiryTimeMillis: DateTime.now()
                  .add(const Duration(days: 30))
                  .millisecondsSinceEpoch
                  .toString(),
              autoRenewing: true,
            ),
          );

          // Mock existing subscription
          final existingSub = UserSubscription(
            id: 'sub-1',
            userId: testUser.id,
            tier: AccessTier.standard,
            status: SubscriptionStatus.expired,
            provider: StoreProvider.google,
            validUntil: DateTime.now().subtract(const Duration(days: 1)),
            originalTransactionId: 'token',
            willAutoRenew: false,
          );

          when(
            () => mockUserSubscriptionRepository.readAll(
              filter: any(named: 'filter'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [existingSub],
              cursor: null,
              hasMore: false,
            ),
          );
          when(
            () => mockUserRepository.read(id: testUser.id),
          ).thenAnswer((_) async => testUser);

          await service.handleGoogleNotification(notification);

          final capturedSub =
              verify(
                    () => mockUserSubscriptionRepository.update(
                      id: existingSub.id,
                      item: captureAny(named: 'item'),
                    ),
                  ).captured.first
                  as UserSubscription;
          expect(capturedSub.status, SubscriptionStatus.active);
          expect(capturedSub.willAutoRenew, true);

          final capturedUser =
              verify(
                    () => mockUserRepository.update(
                      id: testUser.id,
                      item: captureAny(named: 'item'),
                    ),
                  ).captured.first
                  as User;
          expect(capturedUser.tier, AccessTier.premium);
        },
      );

      test(
        'updates subscription to non-renewing (Canceled) but keeps access if expiry is in future',
        () async {
          // Mock Google Client: Auto-renew OFF, Expiry FUTURE
          when(
            () => mockGooglePlayClient.getSubscription(
              subscriptionId: any(named: 'subscriptionId'),
              purchaseToken: any(named: 'purchaseToken'),
            ),
          ).thenAnswer(
            (_) async => GoogleSubscriptionPurchase(
              expiryTimeMillis: DateTime.now()
                  .add(const Duration(days: 10))
                  .millisecondsSinceEpoch
                  .toString(),
              autoRenewing: false, // User turned it off
            ),
          );

          // Existing Sub: Active, Auto-renew ON
          final existingSub = UserSubscription(
            id: 'sub-1',
            userId: testUser.id,
            tier: AccessTier.premium,
            status: SubscriptionStatus.active,
            provider: StoreProvider.google,
            validUntil: DateTime.now().add(const Duration(days: 10)),
            originalTransactionId: 'token',
            willAutoRenew: true,
          );

          when(
            () => mockUserSubscriptionRepository.readAll(
              filter: any(named: 'filter'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [existingSub],
              cursor: null,
              hasMore: false,
            ),
          );
          when(
            () => mockUserRepository.read(id: testUser.id),
          ).thenAnswer(
            (_) async => testUser.copyWith(tier: AccessTier.premium),
          );

          await service.handleGoogleNotification(notification);

          // Verify Update: Status Active, WillAutoRenew False
          final capturedSub =
              verify(
                    () => mockUserSubscriptionRepository.update(
                      id: existingSub.id,
                      item: captureAny(named: 'item'),
                    ),
                  ).captured.first
                  as UserSubscription;

          expect(capturedSub.status, SubscriptionStatus.active);
          expect(capturedSub.willAutoRenew, false);

          // User should NOT be updated (already premium)
          verifyNever(
            () => mockUserRepository.update(
              id: any(named: 'id'),
              item: any(named: 'item'),
            ),
          );
        },
      );

      test('downgrades user on EXPIRED Google notification', () async {
        // Mock Google Client to return EXPIRED subscription
        when(
          () => mockGooglePlayClient.getSubscription(
            subscriptionId: any(named: 'subscriptionId'),
            purchaseToken: any(named: 'purchaseToken'),
          ),
        ).thenAnswer(
          (_) async => GoogleSubscriptionPurchase(
            expiryTimeMillis: DateTime.now()
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch
                .toString(),
            autoRenewing: false,
          ),
        );

        // Mock existing active subscription
        final activeSub = UserSubscription(
          id: 'sub-1',
          userId: testUser.id,
          tier: AccessTier.premium,
          status: SubscriptionStatus.active,
          provider: StoreProvider.google,
          validUntil: DateTime.now().add(const Duration(days: 30)),
          originalTransactionId: 'token',
          willAutoRenew: true,
        );

        when(
          () => mockUserSubscriptionRepository.readAll(
            filter: any(named: 'filter'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [activeSub],
            cursor: null,
            hasMore: false,
          ),
        );
        when(
          () => mockUserRepository.read(id: testUser.id),
        ).thenAnswer((_) async => testUser.copyWith(tier: AccessTier.premium));

        await service.handleGoogleNotification(notification);

        final capturedSub =
            verify(
                  () => mockUserSubscriptionRepository.update(
                    id: activeSub.id,
                    item: captureAny(named: 'item'),
                  ),
                ).captured.first
                as UserSubscription;
        expect(capturedSub.status, SubscriptionStatus.expired);
        expect(capturedSub.willAutoRenew, false);

        final capturedUser =
            verify(
                  () => mockUserRepository.update(
                    id: testUser.id,
                    item: captureAny(named: 'item'),
                  ),
                ).captured.first
                as User;
        expect(capturedUser.tier, AccessTier.standard);
      });

      test('logs warning and returns if subscription not found', () async {
        when(
          () => mockGooglePlayClient.getSubscription(
            subscriptionId: any(named: 'subscriptionId'),
            purchaseToken: any(named: 'purchaseToken'),
          ),
        ).thenAnswer(
          (_) async => GoogleSubscriptionPurchase(
            expiryTimeMillis: DateTime.now().millisecondsSinceEpoch.toString(),
            autoRenewing: true,
          ),
        );

        when(
          () => mockUserSubscriptionRepository.readAll(
            filter: any(named: 'filter'),
          ),
        ).thenAnswer(
          (_) async =>
              const PaginatedResponse(items: [], cursor: null, hasMore: false),
        );

        await service.handleGoogleNotification(notification);

        verify(() => mockLogger.warning(any())).called(1);
        verifyNever(
          () => mockUserSubscriptionRepository.update(
            id: any(named: 'id'),
            item: any(named: 'item'),
          ),
        );
      });

      test('rethrows exception when Google API fails', () async {
        when(
          () => mockGooglePlayClient.getSubscription(
            subscriptionId: any(named: 'subscriptionId'),
            purchaseToken: any(named: 'purchaseToken'),
          ),
        ).thenThrow(Exception('Google API Error'));

        expect(
          () => service.handleGoogleNotification(notification),
          throwsException,
        );
      });

      test('ignores notification if subscription details are null', () async {
        const emptyNotification = GoogleSubscriptionNotification(
          version: '1.0',
          packageName: 'com.example',
          eventTimeMillis: '123',
        );
        await service.handleGoogleNotification(emptyNotification);
        verifyNever(
          () => mockGooglePlayClient.getSubscription(
            subscriptionId: any(named: 'subscriptionId'),
            purchaseToken: any(named: 'purchaseToken'),
          ),
        );
      });
    });
  });
}
